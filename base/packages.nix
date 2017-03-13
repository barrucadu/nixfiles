{ config, pkgs, ... }:

let
  haveX = config.services.xserver.enable;
in

{
  nixpkgs.config = {
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

  # Default packages
  environment.systemPackages = with pkgs;
    let
      common = [
        aspell
        aspellDicts.en
        direnv
        file
        git
        gnupg
        gnupg1compat
        fortune
        haskellPackages.hledger
        haskellPackages.pandoc
        htop
        imagemagick
        lynx
        man-pages
        mosh
        nmap
        nox
        psmisc
        python3
        python3Packages.pygments
        rxvt_unicode.terminfo
        stow
        taskwarrior
        tmux
        unzip
        vim
        which
        whois
        wget
      ];

      noxorg = [
        emacs25-nox
      ];

      xorg = [
        chromium
        clawsMail
        emacs25
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
      ];
    in common ++ (if haveX then xorg else noxorg);
}
