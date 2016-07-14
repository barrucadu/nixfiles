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
        cabal-install
        clang
        direnv
        file
        gcc
        gdb
        ghc
        git
        gitAndTools.gitAnnex
        gnumake
        gnupg
        gnupg1compat
        haskellPackages.cpphs
        haskellPackages.haddock
        haskellPackages.hlint
        haskellPackages.hscolour
        haskellPackages.pandoc
        htop
        imagemagick
        man-pages
        mosh
        m4
        pkgconfig
        psmisc
        python3
        python3Packages.pygments
        python3Packages.virtualenv
        rxvt_unicode.terminfo
        stack
        stow
        tmux
        unzip
        valgrind
        vim
        which
        whois
        wget
      ];

      noxorg = [
        emacs24-nox
      ];

      xorg = [
        chromium
        clawsMail
        emacs24
        evince
        firefox
        ghostscript
        gimp
        mirage
        mpv
        scribus
        scrot
        rxvt_unicode
      ];
    in common ++ (if haveX then xorg else noxorg);
}
