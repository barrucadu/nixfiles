{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-22.05";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.nixpkgs-22_05.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, nixpkgs-unstable, sops-nix, ... }@flakeInputs:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; };
      pkgsUnstable = import nixpkgs-unstable { inherit system; };
      specialArgs = { inherit flakeInputs pkgsUnstable; };
    in
    {
      formatter.${system} = pkgs.nixpkgs-fmt;

      nixosConfigurations.azathoth = nixpkgs.lib.nixosSystem {
        inherit specialArgs system;
        modules = [
          ./common.nix
          ./hosts/azathoth/configuration.nix
          ./hosts/azathoth/hardware.nix
          "${nixpkgs}/nixos/modules/installer/scan/not-detected.nix"
        ];
      };

      nixosConfigurations.carcosa = nixpkgs.lib.nixosSystem {
        inherit specialArgs system;
        modules = [
          ./common.nix
          ./hosts/carcosa/configuration.nix
          ./hosts/carcosa/hardware.nix
          "${nixpkgs}/nixos/modules/profiles/qemu-guest.nix"
          sops-nix.nixosModules.sops
        ];
      };

      nixosConfigurations.lainonlife = nixpkgs.lib.nixosSystem {
        inherit specialArgs system;
        modules = [
          ./common.nix
          ./hosts/lainonlife/configuration.nix
          ./hosts/lainonlife/hardware.nix
          "${nixpkgs}/nixos/modules/installer/scan/not-detected.nix"
          sops-nix.nixosModules.sops
        ];
      };

      nixosConfigurations.nyarlathotep = nixpkgs.lib.nixosSystem {
        inherit specialArgs system;
        modules = [
          ./common.nix
          ./hosts/nyarlathotep/configuration.nix
          ./hosts/nyarlathotep/hardware.nix
          "${nixpkgs}/nixos/modules/installer/scan/not-detected.nix"
          sops-nix.nixosModules.sops
        ];
      };

      packages.${system} = {
        backups =
          let
            pythonEnv = pkgs.python3.buildEnv.override { extraLibs = with pkgs.python3Packages; [ boto3 ]; };
          in
          pkgs.writeShellScriptBin "backups.sh" ''
            #!${pkgs.bash}

            PATH=${pkgs.duplicity}/bin:${pkgs.python3}/bin:${pkgs.sops}/bin:${pkgs.nettools}/bin
            PYTHONPATH="${pythonEnv}/${pkgs.python3.sitePackages}/"

            ${pkgs.lib.fileContents ./scripts/backups.sh}
          '';

        lint =
          pkgs.writeShellScriptBin "lint.sh" ''
            #!${pkgs.bash}

            PATH=${pkgs.nix-linter}/bin:${pkgs.shellcheck}/bin

            ${pkgs.lib.fileContents ./scripts/lint.sh}
          '';

        secrets =
          pkgs.writeShellScriptBin "backups.sh" ''
            #!${pkgs.bash}

            PATH=${pkgs.sops}/bin:${pkgs.nettools}/bin
            EDITOR=${pkgs.vim}/bin/vim

            ${pkgs.lib.fileContents ./scripts/secrets.sh}
          '';
      };
    };
}
