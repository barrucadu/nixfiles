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
  };

  environment.systemPackages = with pkgs; [
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

    # Shells
    zsh

    # Miscellaneous
    mosh
    tmux
    stow
    file
  ];
}
