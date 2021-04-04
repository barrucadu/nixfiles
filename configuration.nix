{
  imports = [
    ./common.nix
    ./host/configuration.nix
    ./host/hardware.nix
    ./services/bookdb.nix
    ./services/bookmarks.nix
    ./services/caddy.nix
    ./services/commento.nix
    ./services/concourse.nix
    ./services/etherpad.nix
    ./services/finder.nix
    ./services/gitea.nix
    ./services/minecraft.nix
    ./services/pleroma.nix
    ./services/umami.nix
  ];
}
