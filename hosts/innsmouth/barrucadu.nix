{ config, pkgs, ... }:

{
  networking.firewall.enable = false;

  services.nginx.enable = true;
  services.nginx.virtualHosts = {
    "barrucadu.co.uk".globalRedirect = "www.barrucadu.co.uk";

    "www.barrucadu.co.uk" = {
      root = "/srv/http/www";
      locations."/bookdb/".proxyPass = "http://127.0.0.1:3000";
      locations."/bookdb/covers/".extraConfig   = "alias /srv/bookdb/covers/;";
      locations."/bookdb/script.js".extraConfig = "alias /srv/bookdb/script.js;";
      locations."/bookdb/style.css".extraConfig = "alias /srv/bookdb/style.css;";
      extraConfig = ''
        include /srv/http/www.conf;
        access_log /dev/null;
        error_log  /var/spool/nginx/logs/www.error.log;
      '';
    };

    "docs.barrucadu.co.uk" = {
      root = "/srv/http/docs";
      extraConfig = ''
        include ${pkgs.nginx}/conf/mime.types;
        types { text/html go; }
        access_log /dev/null;
        error_log  /var/spool/nginx/logs/docs.error.log;
      '';
    };

    "go.barrucadu.co.uk" = {
      root = "/srv/http/go";
      extraConfig = ''
        include /srv/http/go.conf;
        access_log /dev/null;
        error_log  /var/spool/nginx/logs/go.error.log;
      '';
    };

    "memo.barrucadu.co.uk" = {
      root = "/srv/http/memo";
      extraConfig = ''
        access_log /dev/null;
        error_log  /var/spool/nginx/logs/memo.error.log;
      '';
    };

    "misc.barrucadu.co.uk" = {
      root = "/srv/http/misc";
      locations."/pub/".extraConfig = "autoindex on;";
      extraConfig = ''
        access_log /dev/null;
        error_log  /var/spool/nginx/logs/misc.error.log;
      '';
    };
  };

  systemd.services.bookdb =
    { enable   = true
    ; wantedBy = [ "multi-user.target" ]
    ; after    = [ "network.target" ]
    ; serviceConfig =
      { ExecStart = "/bin/bookdb run bookdb.conf"
      ; Restart   = "on-failure"
      ; WorkingDirectory = "/srv/bookdb"
      ; }
    ; };

  systemd.services.gopher =
    { enable   = true
    ; wantedBy = [ "multi-user.target" ]
    ; after    = [ "network.target" ]
    ; serviceConfig =
      { ExecStart = "/bin/gopherd"
      ; Restart   = "on-failure"
      ; WorkingDirectory = "/srv/gopher"
      ; }
    ; };

  # Clear the misc files every so often (this needs a user created, as
  # just specifying an arbitrary UID doesn't work)
  systemd.tmpfiles.rules =
    [ "d /srv/http/misc     0755 barrucadu users 3d"
      "d /srv/http/misc/pub 0755 barrucadu users 3d"
    ];
  users.extraUsers.barrucadu = {
    uid = 1000;
    group = "users";
  };
}
