{ config, ... }:

{
  systemd.services.bookdb =
    { enable   = true
    ; wantedBy = [ "multi-user.target" ]
    ; after    = [ "network.target" ]
    ; serviceConfig =
      { ExecStart = "/srv/bookdb/bookdb run bookdb.conf"
      ; Restart   = "on-failure"
      ; WorkingDirectory = "/srv/bookdb"
      ; }
    ; };
}
