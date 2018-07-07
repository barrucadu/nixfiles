{ config, pkgs, lib, ... }:

with lib;

{
  imports = [ ../../services/nginx-phpfpm.nix ];

  networking.firewall.enable = false;

  services.journald.extraConfig = "SystemMaxUse=500M";

  services.nginx.enable = true;
  services.nginx.virtualHosts = {
    "barrucadu.co.uk".globalRedirect = "www.barrucadu.co.uk";

    "www.barrucadu.co.uk" = {
      root = "/srv/http/www";
      locations."/bookdb/".proxyPass = "http://127.0.0.1:3000";
      locations."/bookdb/covers/".extraConfig = "alias /srv/bookdb/covers/;";
      locations."/bookdb/static/".extraConfig = "alias /srv/bookdb/static/;";
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
      locations."~ /7day/.*/".extraConfig    = "autoindex on;";
      locations."~ /14day/.*/".extraConfig   = "autoindex on;";
      locations."~ /28day/.*/".extraConfig   = "autoindex on;";
      locations."~ /forever/.*/".extraConfig = "autoindex on;";
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

  # Logs
  services.logrotate.enable = true;
  services.logrotate.config = ''
${concatMapStringsSep " " (n: "/var/spool/nginx/logs/${n}.error.log") [ "www" "ci" "docs" "go" "memo" "misc" ]} {
    weekly
    copytruncate
    rotate 1
    compress
    postrotate
        systemctl kill nginx.service --signal=USR1
    endscript
}
  '';

  # Clear the misc files every so often (this needs a user created, as
  # just specifying an arbitrary UID doesn't work)
  systemd.tmpfiles.rules =
    [ "d /srv/http/misc/7day  0755 barrucadu users  7d"
      "d /srv/http/misc/14day 0755 barrucadu users 14d"
      "d /srv/http/misc/28day 0755 barrucadu users 28d"
    ];
  users.extraUsers.barrucadu = {
    uid = 1000;
    group = "users";
  };
}
