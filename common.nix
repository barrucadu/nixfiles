{ config, lib, pkgs, ... }:

with lib;

{
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

  # Every machine gets an sshd
  services.openssh = {
    enable = true;

    # Only pubkey auth
    passwordAuthentication = false;
    challengeResponseAuthentication = false;
  };

  # Syncthing for shared folders (configured directly in the syncthing client)
  services.syncthing = {
    enable = true;
    user   = "barrucadu";
  };
  networking.firewall = {
    allowedTCPPorts = [ 22000 ];
    allowedUDPPorts = [ 21027 ];
  };

  # Monitor network activity
  services.vnstat.enable = true;


  #############################################################################
  ## User accounts
  #############################################################################

  programs.zsh.enable = true;

  users.extraUsers.barrucadu = {
    uid = 1000;
    description = "Michael Walker <mike@barrucadu.co.uk>";
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    group = "users";
    initialPassword = "breadbread";
    shell = "/run/current-system/sw/bin/zsh";

    # Such pubkey!
    openssh.authorizedKeys.keys = [
      (import ./files/azathoth-linux-pubkey.nix)
      (import ./files/azathoth-windows-pubkey.nix)
      (import ./files/carter-pubkey.nix)
      (import ./files/innsmouth-pubkey.nix)
      (import ./files/lainonlife-pubkey.nix)
      (import ./files/nyarlathotep-pubkey.nix)
      (import ./files/york-pubkey.nix)
    ];
  };


  #############################################################################
  ## Package management
  #############################################################################

  nixpkgs.config = {
    # Allow packages with non-free licenses.
    allowUnfree = true;

    # Enable chromium plugins.
    chromium = {
      enablePepperFlash = true; # Flash player
    };

    # Enable claws plugins.
    clawsMail = {
      enablePluginFancy = true; # HTML renderer
      enablePluginPgp   = true; # PGP encrypt/decrypt/sign
      enablePluginPdf   = true; # PDF/PS renderer
    };
  };

  # System-wide packages
  environment.systemPackages = with pkgs;
    let
      # Packages to always install.
      common = [
        aspell
        aspellDicts.en
        bind
        file
        git
        gnupg
        gnupg1compat
        gnum4
        fortune
        haskellPackages.hledger
        haskellPackages.pandoc
        htop
        imagemagick
        iotop
        lsof
        lynx
        man-pages
        mosh
        nix-repl
        nmap
        nox
        psmisc
        python3
        rxvt_unicode.terminfo
        sbcl
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
        clawsMail
        emacs
        evince
        firefox
        ghostscript
        gimp
        gmrun
        mirage
        mpv
        scribus
        scrot
        rxvt_unicode
        xclip
      ];
    in common ++ (if config.services.xserver.enable then xorg else noxorg);
}
