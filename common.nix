{ config, lib, pkgs, ... }:

with lib;

{
  options = {
    services = {
      backup-scripts = {
        OnCalendarFull = lib.mkOption { default = "monthly"; };
        OnCalendarIncr = lib.mkOption { default = "Mon, 04:00"; };
        WorkingDirectory = lib.mkOption { default = "/home/barrucadu/backup-scripts"; };
        User = lib.mkOption { default = "barrucadu"; };
        Group = lib.mkOption { default = "users"; };
      };
      monitoring-scripts = {
        OnCalendar = lib.mkOption { default = "hourly"; };
        WorkingDirectory = lib.mkOption { default = "/home/barrucadu/monitoring-scripts"; };
        User = lib.mkOption { default = "barrucadu"; };
        Group = lib.mkOption { default = "users"; };
      };
      zfs = {
        automation = {
          enable = lib.mkOption { default = false; };
        };
      };
    };
  };

  config = {
    #############################################################################
    ## General
    #############################################################################

    # The NixOS release to be compatible with for stateful data such as databases.
    system.stateVersion = "17.03";

    # Only keep the last 500MiB of systemd journal.
    services.journald.extraConfig = "SystemMaxUse=500M";

    # Collect nix store garbage and optimise daily.
    nix.gc.automatic = true;
    nix.optimise.automatic = true;

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
    system.autoUpgrade.channel = https://nixos.org/channels/nixos-20.09;
    system.autoUpgrade.dates = "06:45";

    #############################################################################
    ## ZFS
    #############################################################################

    # Auto-trim is enabled per-pool:
    # run `sudo zpool set autotrim=on <pool>`
    services.zfs.trim.enable = config.services.zfs.automation.enable;
    services.zfs.trim.interval = "weekly";

    # Auto-scrub applies to all pools, no need to set any pool
    # properties.
    services.zfs.autoScrub.enable = config.services.zfs.automation.enable;
    services.zfs.autoScrub.interval = "monthly";

    # Auto-snapshot is enabled per dataset:
    # run `sudo zfs set com.sun:auto-snapshot=true <dataset>`
    services.zfs.autoSnapshot.enable = config.services.zfs.automation.enable;


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
    ## Services
    #############################################################################

    # Ping is enabled
    networking.firewall.allowPing = true;

    # Every machine gets an sshd
    services.openssh = {
      enable = true;

      # Only pubkey auth
      passwordAuthentication = false;
      challengeResponseAuthentication = false;
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

    # Run the docker daemon, just in case it's handy.
    virtualisation.docker.enable = true;
    virtualisation.docker.autoPrune.enable = true;


    #############################################################################
    ## Backups
    #############################################################################

    systemd.timers.backup-scripts-full = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = config.services.backup-scripts.OnCalendarFull;
      };
    };

    systemd.timers.backup-scripts-incr = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = config.services.backup-scripts.OnCalendarIncr;
      };
    };

    systemd.services.backup-scripts-full = {
      description = "Take a full backup";
      serviceConfig.WorkingDirectory = config.services.backup-scripts.WorkingDirectory;
      serviceConfig.ExecStart = "${pkgs.zsh}/bin/zsh --login -c './backup.sh full'";
      serviceConfig.User = config.services.backup-scripts.User;
      serviceConfig.Group = config.services.backup-scripts.Group;
    };

    systemd.services.backup-scripts-incr = {
      description = "Take an incremental backup";
      serviceConfig.WorkingDirectory = config.services.backup-scripts.WorkingDirectory;
      serviceConfig.ExecStart = "${pkgs.zsh}/bin/zsh --login -c './backup.sh incr'";
      serviceConfig.User = config.services.backup-scripts.User;
      serviceConfig.Group = config.services.backup-scripts.Group;
    };


    #############################################################################
    ## Monitoring
    #############################################################################

    systemd.timers.monitoring-scripts = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = config.services.monitoring-scripts.OnCalendar;
      };
    };

    systemd.services.monitoring-scripts = {
      description = "Run monitoring scripts";
      serviceConfig.WorkingDirectory = config.services.monitoring-scripts.WorkingDirectory;
      serviceConfig.ExecStart = "${pkgs.zsh}/bin/zsh --login -c ./monitor.sh";
      serviceConfig.User = config.services.monitoring-scripts.User;
      serviceConfig.Group = config.services.monitoring-scripts.Group;
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
          job_name = "${config.networking.hostName}-docker";
          static_configs = [{ targets = [ "localhost:9417" ]; }];
        }
      ];
    };

    services.prometheus.exporters.node.enable = config.services.prometheus.enable;

    systemd.services.prometheus-docker-exporter = {
      enable = config.services.prometheus.enable;
      description = "Docker exporter for Prometheus";
      after = [ "docker.service" ];
      wantedBy = [ "prometheus.service" ];
      serviceConfig = {
        Restart = "always";
        ExecStartPre = [
          "-${pkgs.docker}/bin/docker stop prometheus_docker_exporter"
          "-${pkgs.docker}/bin/docker rm prometheus_docker_exporter"
          "${pkgs.docker}/bin/docker pull prometheusnet/docker_exporter"
        ];
        ExecStart = "${pkgs.docker}/bin/docker run --rm --name prometheus_docker_exporter --volume \"/var/run/docker.sock\":\"/var/run/docker.sock\" --publish 9417:9417 prometheusnet/docker_exporter";
      };
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
      shell = "/run/current-system/sw/bin/zsh";

      # Such pubkey!
      openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIP5QUiJZ9TX1/fNAAg4UdtSM4AnpIgdSp7FsH1s1mnz barrucadu@azathoth"
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDGsbaoX0seFfMTXePyaQchxU3g58xFMUipZPvddCT8c azathoth-windows"
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFu01w8xJAWNuLFKLv1eZEX7QvOBYfUqi5Ed4yYT70kF barrucadu@dunwich"
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAPBk5s00T7a7YQXNtR6YmxmKRzI/6vfqI93RaVRDuML barrucadu@dreamlands"
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBuyrbZH+Lqu1qUE9NpoOpyv1/avEArueJTco8X3cXlh barrucadu@lainonlife"
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKohcTDKF18ionBANAnGbcG/6lyJqCJWEza5nOss+Sh0 barrucadu@nyarlathotep"
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
    environment.systemPackages = with pkgs;
      let
        # Packages to always install.
        common = [
          aspell
          aspellDicts.en
          bind
          docker_compose
          file
          fortune
          fzf
          git
          gnum4
          gnupg
          gnupg1compat
          htop
          imagemagick
          iotop
          lsof
          lynx
          man-pages
          ncdu
          nmap
          proselint
          psmisc
          python3
          ripgrep
          rsync
          rxvt_unicode.terminfo
          smartmontools
          stow
          tmux
          unzip
          vale
          vim
          vnstat
          wget
          which
          whois
        ];

        # Packages to install if X is not enabled.
        noxorg = [
          emacs-nox
        ];

        # Packages to install if X is enabled.
        xorg = [
          chromium
          emacs
          evince
          firefox
          gimp
          gmrun
          keepassxc
          mpv
          rxvt_unicode
          scrot
          xclip
        ];
      in
      common ++ (if config.services.xserver.enable then xorg else noxorg);
  };
}
