{ config, pkgs, ... }:

let
  haveX = config.services.xserver.enable;
in

{
  nixpkgs.config = {
    allowUnfree = true;

    # Build emacs without X support if xserver not enabled.
    packageOverrides = pkgs:
      let emacs = if haveX then pkgs.emacs24 else pkgs.emacs24-nox;
          emacsWithPackages = (pkgs.emacsPackagesNgGen emacs).emacsWithPackages;
      in {
        emacs = emacsWithPackages (epkgs: with epkgs; [
          auctex
          color-theme
          haskell-mode
          magit
          markdown-mode
          org
        ]);
      };

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
        cabal-install
        clang
        emacs
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
        htop
        imagemagick
        mosh
        pkgconfig
        psmisc
        python3
        stack
        stow
        tmux
        valgrind
        vim
        which
        wget
      ];

      xorg = [
        chromium
        clawsMail
        evince
        firefox
        gimp
        mirage
        mpv
        scribus
        scrot
        rxvt_unicode
      ];
    in common ++ (if haveX then xorg else []);
}
