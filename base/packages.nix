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
        # Editors
        emacs
        vim

        # Development
        gnumake
        gcc
        clang
        ghc
        stack

        # Version control
        git
        gitAndTools.gitAnnex

        # Shells
        zsh

        # Miscellaneous
        file
        gnupg
        mosh
        stow
        tmux
      ];

      xorg = [
        chromium
        clawsMail
        firefox
        gimp
        herbstluftwm
        mpv
        scribus
        rxvt_unicode
      ];
    in common ++ (if haveX then xorg else []);

  # Eable zsh use as an interactive shell
  programs.zsh.enable = true;
}
