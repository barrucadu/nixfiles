{
  imports = [
    ./common.nix
    ./host/configuration.nix
    ./host/hardware.nix
    ./services/bookdb.nix
    ./services/caddy.nix
    ./services/concourseci.nix
    ./services/pleroma.nix
    ./services/rtorrent.nix
  ];
}
