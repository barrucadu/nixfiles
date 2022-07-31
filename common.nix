{ config, lib, pkgs, flakeInputs, ... }:

with lib;

let
  thereAreZfsFilesystems = any id (mapAttrsToList (_: attrs: attrs.fsType == "zfs") config.fileSystems);
in
{
  imports = [
    ./modules/erase-your-darlings.nix
    ./modules/firewall.nix
    ./services/backups.nix
    ./services/bookdb.nix
    ./services/bookmarks.nix
    ./services/concourse.nix
    ./services/finder.nix
    ./services/foundryvtt.nix
    ./services/minecraft.nix
    ./services/monitoring.nix
    ./services/pleroma.nix
    ./services/resolved.nix
    ./services/umami.nix
    ./services/wikijs.nix
  ];

  config = {
    #############################################################################
    ## General
    #############################################################################

    # The NixOS release to be compatible with for stateful data such as databases.
    system.stateVersion = "22.05";

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

    services.monitoring.scripts.zfs = mkIf thereAreZfsFilesystems ''
      if [[ "$(zpool status -x)" != "all pools are healthy" ]]; then
        zpool status
        exit 1
      fi
    '';

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
    virtualisation.oci-containers.backend = "docker";


    #############################################################################
    ## Monitoring
    #############################################################################

    services.grafana = {
      enable = config.services.prometheus.enable;
      auth.anonymous.enable = true;
      provision.enable = true;
      provision.datasources = [
        {
          name = "prometheus";
          url = "http://localhost:${toString config.services.prometheus.port}";
          type = "prometheus";
        }
      ];
      provision.dashboards = [
        { name = "Node Stats (Detailed)"; folder = "Common"; options.path = ./grafana-dashboards/node-stats-detailed.json; }
        { name = "Container Stats (Detailed)"; folder = "Common"; options.path = ./grafana-dashboards/container-stats-detailed.json; }
      ];
    };

    services.prometheus = {
      enable = true;
      listenAddress = "127.0.0.1";
      port = 9090;
      globalConfig.scrape_interval = "15s";
      scrapeConfigs = [
        {
          job_name = "${config.networking.hostName}-node";
          static_configs = [{ targets = [ "localhost:${toString config.services.prometheus.exporters.node.port}" ]; }];
        }
        {
          job_name = "${config.networking.hostName}-cadvisor";
          static_configs = [{ targets = [ "localhost:${toString config.services.cadvisor.port}" ]; }];
        }
      ];
    };

    services.prometheus.exporters.node.enable = config.services.prometheus.enable;
    # if a disk is mounted at /home, then the default value of
    # `"true"` reports incorrect filesystem metrics
    systemd.services.prometheus-node-exporter.serviceConfig.ProtectHome = mkForce "read-only";

    services.cadvisor = {
      enable = config.services.prometheus.enable;
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
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBuyrbZH+Lqu1qUE9NpoOpyv1/avEArueJTco8X3cXlh barrucadu@lainonlife"
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKohcTDKF18ionBANAnGbcG/6lyJqCJWEza5nOss+Sh0 barrucadu@nyarlathotep"
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJVnNyKbBcHMY7Tcak07bL6svb/x8KXCL5WJRck9PaDI barrucadu@carcosa"
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
      bind
      docker-compose
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
      rsync
      rxvt_unicode.terminfo
      smartmontools
      stow
      tmux
      unzip
      vim
      wget
      which
      whois
      (if config.services.xserver.enable then emacs else emacs-nox)
    ];
  };
}
