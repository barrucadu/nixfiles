{ config, ... }:

{
  # The NixOS release to be compatible with for stateful data such as databases.
  system.stateVersion = "16.03";

  # Clear out /tmp after a fortnight.
  systemd.tmpfiles.rules = [ "d /tmp 1777 root root 14d" ];

  # Pull in the rest of the default configuration
  imports = [
    ./locale.nix
    ./packages.nix
    ./users.nix
  ];
}
