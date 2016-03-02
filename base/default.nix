{ config, ... }:

{
  # The NixOS release to be compatible with for stateful data such as databases.
  system.stateVersion = "15.09";

  imports = [
    ./locale.nix
    ./packages.nix
    ./users.nix
  ];
}
