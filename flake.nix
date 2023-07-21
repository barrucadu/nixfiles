{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs?rev=b6bbc53029a31f788ffed9ea2d459f0bb0f0fbfc";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.nixpkgs-stable.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, sops-nix, nixpkgs-unstable, ... }@flakeInputs:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; };
      pkgsUnstable = import nixpkgs-unstable { inherit system; };
    in
    {
      formatter.${system} = pkgs.nixpkgs-fmt;

      nixosConfigurations =
        let
          mkNixosConfiguration = name: secrets: extraModules: nixpkgs.lib.nixosSystem {
            inherit system;
            specialArgs = { inherit flakeInputs pkgsUnstable; };
            modules = [
              {
                networking.hostName = name;
                nixpkgs.overlays = [ (_: _: { nixfiles = self.packages.${system}; }) ];
              }
              ./shared
              # nix-linter doesn't support the ./hosts/${name}/foo.nix syntax yet
              (./hosts + "/${name}" + /configuration.nix)
              (./hosts + "/${name}" + /hardware.nix)
            ] ++ extraModules ++
            (if secrets then [ sops-nix.nixosModules.sops { sops.defaultSopsFile = ./hosts + "/${name}" + /secrets.yaml; } ] else [ ]);
          };
        in
        {
          azathoth = mkNixosConfiguration "azathoth" false [ "${nixpkgs}/nixos/modules/installer/scan/not-detected.nix" ];
          carcosa = mkNixosConfiguration "carcosa" true [ "${nixpkgs}/nixos/modules/profiles/qemu-guest.nix" ];
          nyarlathotep = mkNixosConfiguration "nyarlathotep" true [ "${nixpkgs}/nixos/modules/installer/scan/not-detected.nix" ];
        };

      packages.${system} =
        {
          bookdb = pkgs.callPackage ./packages/bookdb { };
          bookmarks = pkgs.callPackage ./packages/bookmarks { };
          prometheus-awair-exporter = pkgs.callPackage ./packages/prometheus-awair-exporter { };
          resolved = pkgs.callPackage ./packages/resolved { };
        };

      apps.${system} =
        let
          mkApp = name: script: {
            type = "app";
            program = toString (pkgs.writeShellScript "${name}.sh" script);
          };
        in
        {
          backups = mkApp "backups" ''
            PATH=${with pkgs; lib.makeBinPath [ duplicity sops nettools ]}

            ${pkgs.lib.fileContents ./scripts/backups.sh}
          '';

          fmt = mkApp "fmt" ''
            PATH=${with pkgs; lib.makeBinPath [ nix git python3Packages.black ]}

            ${pkgs.lib.fileContents ./scripts/fmt.sh}
          '';

          lint = mkApp "lint" ''
            # TODO: add nix-linter back when the package is no longer broken
            PATH=${with pkgs; lib.makeBinPath [ findutils shellcheck git gnugrep python3Packages.flake8 ]}

            ${pkgs.lib.fileContents ./scripts/lint.sh}
          '';

          secrets = mkApp "secrets" ''
            PATH=${with pkgs; lib.makeBinPath [ sops nettools vim ]}
            export EDITOR=vim

            ${pkgs.lib.fileContents ./scripts/secrets.sh}
          '';
        };
    };
}
