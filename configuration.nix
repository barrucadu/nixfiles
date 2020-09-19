{
  imports = [
    ./common.nix
    ./host/configuration.nix
    ./host/hardware.nix
    ./services/bookdb.nix
    ./services/bookmarks.nix
    ./services/caddy.nix
    ./services/finder.nix
    ./services/pleroma.nix
  ];
}
