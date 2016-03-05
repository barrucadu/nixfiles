{ config, ... }:

{
  # The NixOS release to be compatible with for stateful data such as databases.
  system.stateVersion = "16.03pre";

  imports = [
    ./locale.nix
    ./packages.nix
    ./users.nix
  ];
}
