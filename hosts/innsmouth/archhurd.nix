{ config, pkgs, lib, ... }:

with lib;

let
  phpExtraConfig = ''
    include ${pkgs.nginx}/conf/fastcgi_params;
    fastcgi_pass  unix:/run/phpfpm/phpfpm.sock;
    fastcgi_index index.php;
    fastcgi_param SCRIPT_FILENAME $document_root/$fastcgi_script_name;
  '';
in
{
  imports =
    [ ../../services/nginx-phpfpm.nix
      ../../services/vsftpd.nix
    ];

  networking.firewall.enable = false;

  services.journald.extraConfig = "SystemMaxUse=500M";

  # Web
  services.nginx.enable = true;
  services.nginx.virtualHosts = {
    "archhurd.org".globalRedirect = "www.archhurd.org";

    "www.archhurd.org" = {
      root = "/srv/http/www";
      locations."/".proxyPass = "http://127.0.0.1:8000";
      locations."/static" = {
        root = "/srv/archweb/archweb/collected_static";
        extraConfig = "rewrite /static(.*) /$1 break;";
      };
      locations."/media".root = "/srv/archweb";
      extraConfig = ''
        access_log /dev/null;
        error_log  /var/spool/nginx/logs/www.error.log;
      '';
    };

    "aur.archhurd.org" = {
      root = "/srv/http/aur/web/html";
      locations."~ \.php$".extraConfig = phpExtraConfig;
      locations."/packages/" = {
        root = "/srv/http/aur/unsupported";
        extraConfig = ''
          autoindex on;
          rewrite /packages/(.*) /$1 break;
        '';
      };
      extraConfig = ''
        index index.php;
        access_log /dev/null;
        error_log  /var/spool/nginx/logs/aur.error.log;
      '';
    };

    "bugs.archhurd.org" = {
      root = "/srv/http/bugs";
      locations."~ \.php$".extraConfig = phpExtraConfig;
      extraConfig = ''
        index index.php;
        access_log /dev/null;
        error_log  /var/spool/nginx/logs/bugs.error.log;
      '';
    };

    "files.archhurd.org" = {
      root = "/srv/http/files";
      locations."/".extraConfig = "autoindex on;";
      extraConfig = ''
        types { application/octet-stream xz; }
        access_log /dev/null;
        error_log  /var/spool/nginx/logs/files.error.log;
      '';
    };

    "lists.archhurd.org" = {
      root = "/srv/http/lists";
      extraConfig = ''
        access_log /dev/null;
        error_log  /var/spool/nginx/logs/lists.error.log;
      '';
    };

    "wiki.archhurd.org" = {
      root = "/srv/http/wiki";
      locations."~ \.php$".extraConfig = phpExtraConfig;
      locations."/wiki".extraConfig = ''
        index index.php;
        rewrite ^/wiki/(.*)$ /index.php?title=$1&$args;
      '';
      locations."/maintenance/".extraConfig = "return 403;";
      locations."^~ /cache/".extraConfig = "deny all;";
      extraConfig = ''
        index index.php;
        access_log /dev/null;
        error_log  /var/spool/nginx/logs/wiki.error.log;
      '';
    };
  };

  systemd.services.archweb =
    { enable   = true
    ; wantedBy = [ "multi-user.target" ]
    ; after    = [ "network.target" ]
    ; serviceConfig =
      { User = "nginx"
      ; WorkingDirectory = "/srv/archweb/archweb"
      ; ExecStart = "/srv/archweb/archweb/start.sh"
      ; }
    ; };

  # Databases
  services.mysql =
    { enable  = true
    ; package = pkgs.mysql
    ; };

  services.postgresql =
    { enable = true
    ; package = pkgs.postgresql95
    ; };

  # FTP
  services.barrucadu-vsftpd =
    { enable = true
    ; anonymousUser = true
    ; anonymousUserNoPassword = true
    ; anonymousUserHome = "/srv/ftp"
    ; };

  # rsync
  services.rsyncd =
    { enable = true
    ; extraConfig = "log file = /var/spool/rsyncd.log"
    ; modules =
      { repos  = { path        = "/srv/rsync/repos"
                 ; comment     = "Arch Hurd repositories"
                 ; "read only" = "yes"
                 ; }
      ; livecd = { path        = "/srv/rsync/livecd"
                 ; comment     = "Arch Hurd LiveCD collection"
                 ; "read only" = "yes"
                 ; }
      ; abs    = { path        = "/srv/rsync/abs"
                 ; comment     = "Arch Build System tree"
                 ; exclude     = ".git .gitignore"
                 ; "read only" = "yes"
                 ; }
      ; }
    ; };

  # Logs
  services.logrotate.enable = true;
  services.logrotate.config = ''
/var/spool/rsyncd.log {
    weekly
    copytruncate
    rotate 1
    compress
}
${concatMapStringsSep " " (n: "/var/spool/nginx/logs/${n}.error.log") [ "www" "aur" "bugs" "files" "lists" "wiki" ]} {
    weekly
    copytruncate
    rotate 1
    compress
    postrotate
        systemctl kill nginx.service --signal=USR1
    endscript
}
  '';

  # Extra packages
  environment.systemPackages = [ pkgs.python2Packages.virtualenv ];
}
