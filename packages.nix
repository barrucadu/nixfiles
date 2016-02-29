{ config, pkgs, ... }:

let
  haveX = config.services.xserver.enable;
in

{
  nixpkgs.config = {
    allowUnfree = true;

    # Build emacs without X support if xserver not enabled.
    packageOverrides = super:
      let self = super.pkgs;
          emacs = if haveX then self.emacs24 else self.emacs24-nox;
	  emacsPackages = if haveX then self.emacsPackages else self.emacsNoXPackages;
      in {
        emacsWithPackages = super.emacsWithPackages.override { emacs = emacs; };
        emacsPackages = self.emacsPackagesGen emacs emacsPackages;
	emacs = self.emacsWithPackages [];
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
