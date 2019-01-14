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
      # nasty hack: selda-sqlite doesn't seem to flush to disk without
      # the connection being closed, so just periodically restart the
      # service.
      ; RuntimeMaxSec = "45m"
      ; }
    ; };
}
