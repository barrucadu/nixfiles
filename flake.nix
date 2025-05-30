{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # my packages
    bookdb = {
      url = "github:barrucadu/bookdb";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.gitignore.follows = "gitignore";
      inputs.rust-overlay.follows = "rust-overlay";
    };
    bookmarks = {
      url = "github:barrucadu/bookmarks";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.gitignore.follows = "gitignore";
      inputs.rust-overlay.follows = "rust-overlay";
    };
    prometheus-awair-exporter = {
      url = "github:barrucadu/prometheus-awair-exporter";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.gitignore.follows = "gitignore";
    };
    resolved = {
      url = "github:barrucadu/resolved";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.gitignore.follows = "gitignore";
      inputs.rust-overlay.follows = "rust-overlay";
    };
    gitignore = {
      url = "github:hercules-ci/gitignore.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, sops-nix, ... }@flakeInputs:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
      };
    in
    {
      formatter.${system} = pkgs.nixpkgs-fmt;

      nixosConfigurations =
        let
          mkNixosConfiguration = name: extraModules: nixpkgs.lib.nixosSystem {
            inherit system;
            specialArgs = { inherit flakeInputs; };
            modules = [
              {
                networking.hostName = name;
                nixpkgs.overlays = [ (_: _: { nixfiles = self.packages.${system}; }) ];
                sops.defaultSopsFile = ./hosts + "/${name}" + /secrets.yaml;
              }
              ./shared
              (./hosts + "/${name}" + /configuration.nix)
              (./hosts + "/${name}" + /hardware.nix)
              sops-nix.nixosModules.sops
            ] ++ extraModules;
          };
        in
        {
          carcosa = mkNixosConfiguration "carcosa" [ "${nixpkgs}/nixos/modules/profiles/qemu-guest.nix" ];
          nyarlathotep = mkNixosConfiguration "nyarlathotep" [ "${nixpkgs}/nixos/modules/installer/scan/not-detected.nix" ];
          yuggoth = mkNixosConfiguration "yuggoth" [ "${nixpkgs}/nixos/modules/profiles/qemu-guest.nix" ];
        };

      packages.${system} =
        {
          bookdb = flakeInputs.bookdb.packages.${system}.default;
          bookmarks = flakeInputs.bookmarks.packages.${system}.default;
          prometheus-awair-exporter = flakeInputs.prometheus-awair-exporter.packages.${system}.default;
          resolved = flakeInputs.resolved.packages.${system}.default;
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
            PATH=${with pkgs; lib.makeBinPath [ restic sops nettools ]}

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

          documentation =
            let
              eval = pkgs.lib.evalModules {
                modules = [
                  { config._module.args = { inherit pkgs; }; }
                  ./shared/options.nix
                  # modules
                  ./shared/acme/options.nix
                  ./shared/bookdb/options.nix
                  ./shared/bookmarks/options.nix
                  ./shared/concourse/options.nix
                  ./shared/erase-your-darlings/options.nix
                  ./shared/finder/options.nix
                  ./shared/foundryvtt/options.nix
                  ./shared/minecraft/options.nix
                  ./shared/oci-containers/options.nix
                  ./shared/pleroma/options.nix
                  ./shared/resolved/options.nix
                  ./shared/restic-backups/options.nix
                  ./shared/torrents/options.nix
                  ./shared/umami/options.nix
                  # host templates
                  ./shared/host-templates/website-mirror/options.nix
                ];
              };
              optionsDoc = pkgs.nixosOptionsDoc {
                options = eval.options;
              };
            in
            mkApp "documentation" ''
              PATH=${with pkgs; lib.makeBinPath [ coreutils gnused mdbook mdbook-admonish python3 ]}
              export NIXOS_OPTIONS_JSON="${optionsDoc.optionsJSON}/share/doc/nixos/options.json"

              ${pkgs.lib.fileContents ./scripts/documentation.sh}
            '';
        };
    };
}
