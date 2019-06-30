{ config, lib, pkgs, ... }:

with lib;

{
  options = {
    services = {
      backup-scripts = {
        OnCalendarFull   = lib.mkOption { default = "monthly"; };
        OnCalendarIncr   = lib.mkOption { default = "Mon, 04:00"; };
        WorkingDirectory = lib.mkOption { default = "/home/barrucadu/backup-scripts"; };
        User             = lib.mkOption { default = "barrucadu"; };
        Group            = lib.mkOption { default = "users"; };
      };
      monitoring-scripts = {
        OnCalendar       = lib.mkOption { default = "hourly"; };
        WorkingDirectory = lib.mkOption { default = "/home/barrucadu/monitoring-scripts"; };
        User             = lib.mkOption { default = "barrucadu"; };
        Group            = lib.mkOption { default = "users"; };
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
      (let mkTmpDir = n: u: "d ${u.home}/tmp 0700 ${n} ${u.group} 7d";
       in mapAttrsToList mkTmpDir (filterAttrs (n: u: u.isNormalUser) config.users.extraUsers));

    # Enable passwd and co.
    users.mutableUsers = true;


    #############################################################################
    ## Locale
    #############################################################################

    # Locale
    i18n.defaultLocale = "en_GB.UTF-8";

    # Timezone
    services.timesyncd.enable = true; # this is enabled by default, but
                                      # I like being explicit about it,
                                      # to remind me.
    time.timeZone = "Europe/London";

    # Keyboard
    i18n.consoleKeyMap = "uk";
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
      user   = "barrucadu";
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

    services.influxdb.enable = true;

    systemd.services.telegraf= {
      path = with pkgs; [smartmontools iputils];

      # hacky solution to make ping work
      serviceConfig.User = lib.mkOverride 99 "root";
    };

    services.telegraf = {
      enable = true;
      extraConfig =
        let interestingHosts = ["barrucadu.co.uk" "gov.uk" "google.com"];
            interestingIPs   = ["1.1.1.1" "8.8.8.8"];
        in {
        agent = { interval = "30s"; };
        outputs = {
          influxdb = { urls = ["http://localhost:8086"]; database = "telegraf"; };
        };
        inputs = {
          cpu = { percpu = true; report_active = true; };
          disk = { ignore_fs = ["devtmpfs" "devpts" "tmpfs" "hugelbfs" "mqueue" "proc" "nfsd" "ramfs" "sysfs" "securityfs" "cgroup2" "cgroup" "efivarfs" "pstore" "debugfs" "rpc_pipefs"]; };
          diskio = {};
          dns_query = { servers = interestingIPs; domains = interestingHosts; };
          http_response = map (host: {address = "https://www.${host}";}) interestingHosts;
          mem = {};
          net = {};
          netstat = {};
          ping = { urls = interestingIPs ++ interestingHosts; count = 1; };
          processes = {};
          smart = {};
          system = {};
          zfs = {};
        };
      };
    };

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
        (import ./files/azathoth-linux-pubkey.nix)
        (import ./files/azathoth-windows-pubkey.nix)
        (import ./files/carter-pubkey.nix)
        (import ./files/dunwich-pubkey.nix)
        (import ./files/lainonlife-pubkey.nix)
        (import ./files/nyarlathotep-pubkey.nix)
      ];
    };


    #############################################################################
    ## Package management
    #############################################################################

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
          fzf
          git
          gnupg
          gnupg1compat
          gnum4
          fortune
          htop
          imagemagick
          iotop
          lsof
          lynx
          man-pages
          ncdu
          nmap
          psmisc
          python3
          ripgrep
          rsync
          rxvt_unicode.terminfo
          smartmontools
          stow
          tmux
          unzip
          vim
          vnstat
          which
          whois
          wget
        ];

        # Packages to install if X is not enabled.
        noxorg = [
          emacs25-nox
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
      in common ++ (if config.services.xserver.enable then xorg else noxorg);
  };
}
