{ config, lib, pkgs, flakeInputs, ... }:

with lib;

let
  promcfg = config.services.prometheus;
  nodeExporter = promcfg.enable && config.services.prometheus.exporters.node.enable;
  cAdvisor = promcfg.enable && config.services.cadvisor.enable;

  thereAreZfsFilesystems = any id (mapAttrsToList (_: attrs: attrs.fsType == "zfs") config.fileSystems);

  firewallcfg = config.nixfiles.firewall;
  readBlocklistFromFile = ''
    cat ${firewallcfg.ipBlocklistFile} | sed 's/\s//g' | sed 's/#.*$//' | grep . | while read ip; do
      iptables -A barrucadu-ip-blocklist -s "$ip" -j DROP
    done
  '';
in
{
  imports = [
    ./backups
    ./bookdb
    ./bookmarks
    ./concourse
    ./erase-your-darlings
    ./finder
    ./foundryvtt
    ./minecraft
    ./oci-containers
    ./pleroma
    ./resolved
    ./umami
  ];

  options.nixfiles.firewall = {
    ipBlocklistFile = mkOption { type = types.nullOr types.str; default = null; };
  };

  config = {
    #############################################################################
    ## General
    #############################################################################

    # The NixOS release to be compatible with for stateful data such as databases.
    system.stateVersion = "22.11";

    # Only keep the last 500MiB of systemd journal.
    services.journald.extraConfig = "SystemMaxUse=500M";

    # Collect nix store garbage and optimise daily.
    nix.gc.automatic = true;
    nix.gc.options = "--delete-older-than 30d";
    nix.optimise.automatic = true;

    # Enable flakes & pin nixpkgs to the same version that built the
    # system
    nix.extraOptions = "experimental-features = nix-command flakes";
    nix.registry.nixpkgs.flake = flakeInputs.nixpkgs;

    # Clear out /tmp after a fortnight and give all normal users a ~/tmp
    # cleaned out weekly.
    systemd.tmpfiles.rules = [ "d /tmp 1777 root root 14d" ] ++
      (
        let mkTmpDir = n: u: "d ${u.home}/tmp 0700 ${n} ${u.group} 7d";
        in mapAttrsToList mkTmpDir (filterAttrs (_: u: u.isNormalUser) config.users.extraUsers)
      );

    # Enable passwd and co.
    users.mutableUsers = true;

    # Upgrade packages and reboot if needed
    system.autoUpgrade.enable = true;
    system.autoUpgrade.allowReboot = true;
    system.autoUpgrade.flags = [ "--update-input" "nixpkgs" ];
    system.autoUpgrade.flake = "/etc/nixos";
    system.autoUpgrade.dates = "06:45";

    #############################################################################
    ## Locale
    #############################################################################

    # Locale
    i18n.defaultLocale = "en_GB.UTF-8";

    # Timezone
    services.timesyncd.enable = true;
    time.timeZone = "Europe/London";

    # Keyboard
    console.keyMap = "uk";
    services.xserver.layout = "gb";

    #############################################################################
    ## Firewall
    #############################################################################

    networking.firewall.enable = true;
    networking.firewall.allowPing = true;
    networking.firewall.trustedInterfaces = if config.virtualisation.docker.enable then [ "docker0" ] else [ ];

    services.fail2ban.enable = true;

    networking.firewall.extraCommands = ''
      iptables -N barrucadu-ip-blocklist
      ${if firewallcfg.ipBlocklistFile == null then "" else readBlocklistFromFile}
      iptables -A barrucadu-ip-blocklist -j RETURN
      iptables -A INPUT -j barrucadu-ip-blocklist
    '';

    networking.firewall.extraStopCommands = ''
      if iptables -n --list barrucadu-ip-blocklist &>/dev/null; then
        iptables -D INPUT -j barrucadu-ip-blocklist
        iptables -F barrucadu-ip-blocklist
        iptables -X barrucadu-ip-blocklist
      fi
    '';

    #############################################################################
    ## ZFS
    #############################################################################

    # Auto-trim is enabled per-pool:
    # run `sudo zpool set autotrim=on <pool>`
    services.zfs.trim.enable = thereAreZfsFilesystems;
    services.zfs.trim.interval = "weekly";

    # Auto-scrub applies to all pools, no need to set any pool
    # properties.
    services.zfs.autoScrub.enable = thereAreZfsFilesystems;
    services.zfs.autoScrub.interval = "monthly";

    # Auto-snapshot is enabled per dataset:
    # run `sudo zfs set com.sun:auto-snapshot=true <dataset>`
    #
    # The default of 12 monthly snapshots takes up too much disk space
    # in practice.
    services.zfs.autoSnapshot.enable = thereAreZfsFilesystems;
    services.zfs.autoSnapshot.monthly = 3;

    services.prometheus.rules = mkIf thereAreZfsFilesystems [
      ''
        groups:
        - name: zfs
          rules:
          - alert: ZPoolStatusDegraded
            expr: node_zfs_zpool_state{state!="online"} > 0
      ''
    ];

    #############################################################################
    ## Services
    #############################################################################

    # Every machine gets an sshd
    services.openssh = {
      enable = true;

      # Only pubkey auth
      passwordAuthentication = false;
      kbdInteractiveAuthentication = false;
    };

    # Start ssh-agent as a systemd user service
    programs.ssh.startAgent = true;

    # Mosh
    programs.mosh = {
      enable = true;
      # make `who` work
      withUtempter = true;
    };

    # Syncthing for shared folders (configured directly in the syncthing client)
    services.syncthing = {
      enable = true;
      user = "barrucadu";
      openDefaultPorts = true;
    };

    # Use docker for all the OCI container based services
    virtualisation.docker.enable = true;
    virtualisation.docker.autoPrune.enable = true;

    #############################################################################
    ## Dashboards & Alerting
    #############################################################################

    services.grafana = {
      enable = promcfg.enable;
      settings."auth.anonymous".enabled = true;
      provision.enable = true;
      provision.datasources.settings.datasources = mkIf promcfg.enable [
        {
          name = "prometheus";
          url = "http://localhost:${toString promcfg.port}";
          type = "prometheus";
        }
      ];
      provision.dashboards.settings.providers =
        let
          nodeExporterDashboard = { name = "Node Stats (Detailed)"; folder = "Common"; options.path = ./dashboards/node-stats-detailed.json; };
          cAdvisorDashboard = { name = "Container Stats (Detailed)"; folder = "Common"; options.path = ./dashboards/container-stats-detailed.json; };
        in
        (if nodeExporter then [ nodeExporterDashboard ] else [ ]) ++
        (if cAdvisor then [ cAdvisorDashboard ] else [ ]);
    };

    services.prometheus = {
      enable = true;
      listenAddress = "127.0.0.1";
      port = 9090;
      globalConfig.scrape_interval = "15s";
      scrapeConfigs =
        let
          nodeExporterScraper = {
            job_name = "${config.networking.hostName}-node";
            static_configs = [{ targets = [ "localhost:${toString promcfg.exporters.node.port}" ]; }];
          };
          cAdvisorScraper = {
            job_name = "${config.networking.hostName}-cadvisor";
            static_configs = [{ targets = [ "localhost:${toString config.services.cadvisor.port}" ]; }];
          };
        in
        (if nodeExporter then [ nodeExporterScraper ] else [ ]) ++
        (if cAdvisor then [ cAdvisorScraper ] else [ ]);
      alertmanagers = mkIf promcfg.alertmanager.enable [
        {
          static_configs = [{ targets = [ "localhost:${toString promcfg.alertmanager.port}" ]; }];
        }
      ];
    };

    services.prometheus.alertmanager = {
      enable = promcfg.enable;
      port = 9093;
      configuration = {
        route = {
          group_by = [ "alertname" ];
          repeat_interval = "6h";
          receiver = "aws-sns";
        };
        receivers = [
          {
            name = "aws-sns";
            sns_configs = [{
              sigv4 = { region = "eu-west-1"; };
              topic_arn = "arn:aws:sns:eu-west-1:197544591260:host-notifications";
              subject = "Alert: ${config.networking.hostName}";
            }];
          }
        ];
      };
    };

    # Host metrics
    services.prometheus.exporters.node.enable = promcfg.enable;

    # if a disk is mounted at /home, then the default value of
    # `"true"` reports incorrect filesystem metrics
    systemd.services.prometheus-node-exporter.serviceConfig.ProtectHome = mkForce "read-only";

    # Container metrics
    services.cadvisor = {
      enable = promcfg.enable;
      port = 9418;
    };

    #############################################################################
    ## User accounts
    #############################################################################

    programs.zsh.enable = true;

    users.extraUsers.barrucadu = {
      uid = 1000;
      description = "Michael Walker <mike@barrucadu.co.uk>";
      isNormalUser = true;
      extraGroups = [ "docker" "wheel" ];
      group = "users";
      initialPassword = "breadbread";
      shell = pkgs.zsh;

      # Such pubkey!
      openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIP5QUiJZ9TX1/fNAAg4UdtSM4AnpIgdSp7FsH1s1mnz barrucadu@azathoth"
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDGsbaoX0seFfMTXePyaQchxU3g58xFMUipZPvddCT8c azathoth-windows"
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKohcTDKF18ionBANAnGbcG/6lyJqCJWEza5nOss+Sh0 barrucadu@nyarlathotep"
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJVnNyKbBcHMY7Tcak07bL6svb/x8KXCL5WJRck9PaDI barrucadu@carcosa"
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJ5qZ+i88qWduVQHjnfm3KFdUnTOI0HBqBufGMfk/CkR yog-sothoth"
      ];
    };


    #############################################################################
    ## Package management
    #############################################################################

    # gnupg doesn't come with pinentry, so require the agent
    programs.gnupg.agent.enable = true;

    # Allow packages with non-free licenses.
    nixpkgs.config.allowUnfree = true;

    # System-wide packages
    environment.systemPackages = with pkgs; [
      aspell
      aspellDicts.en
      atuin
      bind
      docker-compose
      chezmoi
      emacs
      fd
      file
      fortune
      fzf
      git
      gnum4
      gnupg
      gnupg1compat
      haskellPackages.hledger
      htop
      imagemagick
      iotop
      lsof
      lynx
      man-pages
      ncdu
      psmisc
      python3
      ripgrep
      rsync
      rxvt_unicode.terminfo
      shellcheck
      smartmontools
      stow
      tmux
      unzip
      vim
      wget
      which
      whois
    ];
  };
}
