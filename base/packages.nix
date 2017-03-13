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
        go_1_6
        gnumake
        gnupg
        gnupg1compat
        fortune
        haskellPackages.cpphs
        haskellPackages.haddock
        haskellPackages.hledger
        haskellPackages.hlint
        haskellPackages.hscolour
        haskellPackages.pandoc
        htop
        imagemagick
        lynx
        man-pages
        mosh
        m4
        nmap
        nox
        pkgconfig
        psmisc
        python3
        python2Packages.virtualenv
        python3Packages.pygments
        python3Packages.virtualenv
        rxvt_unicode.terminfo
        stack
        stow
        taskwarrior
        tmux
        unzip
        valgrind
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
