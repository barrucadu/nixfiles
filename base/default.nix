{ config, ... }:

{
  # The NixOS release to be compatible with for stateful data such as databases.
  system.stateVersion = "16.09";

  # Clear out /tmp after a fortnight.
  systemd.tmpfiles.rules = [ "d /tmp 1777 root root 14d" ];

  # Collect nix store garbage daily.
  nix.gc.automatic = true;
  nix.gc.dates = "03:15";

  # Pull in the rest of the default configuration
  imports = [
    ./locale.nix
    ./packages.nix
    ./users.nix
  ];
}
