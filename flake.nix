{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-22.11";
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, sops-nix, ... }@flakeInputs:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; };
      specialArgs = { inherit flakeInputs; };
    in
    {
      formatter.${system} = pkgs.nixpkgs-fmt;

      nixosConfigurations.azathoth = nixpkgs.lib.nixosSystem {
        inherit specialArgs system;
        modules = [
          ./shared
          ./hosts/azathoth/configuration.nix
          ./hosts/azathoth/hardware.nix
          "${nixpkgs}/nixos/modules/installer/scan/not-detected.nix"
        ];
      };

      nixosConfigurations.carcosa = nixpkgs.lib.nixosSystem {
        inherit specialArgs system;
        modules = [
          ./shared
          ./hosts/carcosa/configuration.nix
          ./hosts/carcosa/hardware.nix
          "${nixpkgs}/nixos/modules/profiles/qemu-guest.nix"
          sops-nix.nixosModules.sops
        ];
      };

      nixosConfigurations.lainonlife = nixpkgs.lib.nixosSystem {
        inherit specialArgs system;
        modules = [
          ./shared
          ./hosts/lainonlife/configuration.nix
          ./hosts/lainonlife/hardware.nix
          "${nixpkgs}/nixos/modules/installer/scan/not-detected.nix"
          sops-nix.nixosModules.sops
        ];
      };

      nixosConfigurations.nyarlathotep = nixpkgs.lib.nixosSystem {
        inherit specialArgs system;
        modules = [
          ./shared
          ./hosts/nyarlathotep/configuration.nix
          ./hosts/nyarlathotep/hardware.nix
          "${nixpkgs}/nixos/modules/installer/scan/not-detected.nix"
          sops-nix.nixosModules.sops
        ];
      };

      packages.${system} = {
        backups =
          pkgs.writeShellScriptBin "backups.sh" ''
            PATH=${with pkgs; lib.makeBinPath [ duplicity sops nettools ]}

            ${pkgs.lib.fileContents ./scripts/backups.sh}
          '';

        lint =
          pkgs.writeShellScriptBin "lint.sh" ''
            PATH=${with pkgs; lib.makeBinPath [ findutils nix-linter shellcheck git gnugrep ]}

            ${pkgs.lib.fileContents ./scripts/lint.sh}
          '';

        secrets =
          pkgs.writeShellScriptBin "backups.sh" ''
            PATH=${with pkgs; lib.makeBinPath [ sops nettools vim ]}
            export EDITOR=vim

            ${pkgs.lib.fileContents ./scripts/secrets.sh}
          '';
      };
    };
}
