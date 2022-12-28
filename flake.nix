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
    in
    {
      formatter.${system} = pkgs.nixpkgs-fmt;

      nixosConfigurations =
        let
          mkNixosConfiguration = name: extraModules: nixpkgs.lib.nixosSystem {
            inherit system;
            specialArgs = { inherit flakeInputs; };
            modules = [
              ./shared
              # nix-linter doesn't support the ./hosts/${name}/foo.nix syntax yet
              (./hosts + "/${name}" + /configuration.nix)
              (./hosts + "/${name}" + /hardware.nix)
            ] ++ extraModules;
          };
        in
        {
          azathoth = mkNixosConfiguration "azathoth" [ "${nixpkgs}/nixos/modules/installer/scan/not-detected.nix" ];
          carcosa = mkNixosConfiguration "carcosa" [ "${nixpkgs}/nixos/modules/profiles/qemu-guest.nix" sops-nix.nixosModules.sops ];
          lainonlife = mkNixosConfiguration "lainonlife" [ "${nixpkgs}/nixos/modules/installer/scan/not-detected.nix" sops-nix.nixosModules.sops ];
          nyarlathotep = mkNixosConfiguration "nyarlathotep" [ "${nixpkgs}/nixos/modules/installer/scan/not-detected.nix" sops-nix.nixosModules.sops ];
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
            PATH=${with pkgs; lib.makeBinPath [ findutils nix-linter shellcheck git gnugrep python3Packages.flake8 ]}

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
