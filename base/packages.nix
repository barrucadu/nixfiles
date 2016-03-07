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
        haskellPackages.hlint
        htop
        imagemagick
        mosh
        psmisc
        python3
        stack
        stow
        tmux
        valgrind
        vim
        wget
      ];

      xorg = [
        chromium
        clawsMail
        firefox
        gimp
        mirage
        mpv
        scribus
        rxvt_unicode
      ];
    in common ++ (if haveX then xorg else []);
}
