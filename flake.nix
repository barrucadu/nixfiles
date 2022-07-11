{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-22.05";

  outputs = { nixpkgs, ... }: {
    nixosConfigurations.azathoth = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ./common.nix
        ./hosts/azathoth/configuration.nix
        ./hosts/azathoth/hardware.nix
        "${nixpkgs}/nixos/modules/installer/scan/not-detected.nix"
      ];
    };

    nixosConfigurations.carcosa = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ./common.nix
        ./hosts/carcosa/configuration.nix
        ./hosts/carcosa/hardware.nix
        "${nixpkgs}/nixos/modules/profiles/qemu-guest.nix"
      ];
    };

    nixosConfigurations.lainonlife = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ./common.nix
        ./hosts/lainonlife/configuration.nix
        ./hosts/lainonlife/hardware.nix
        "${nixpkgs}/nixos/modules/installer/scan/not-detected.nix"
      ];
    };

    nixosConfigurations.nyarlathotep = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ./common.nix
        ./hosts/nyarlathotep/configuration.nix
        ./hosts/nyarlathotep/hardware.nix
        "${nixpkgs}/nixos/modules/installer/scan/not-detected.nix"
      ];
    };
  };
}
