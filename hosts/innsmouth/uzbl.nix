{ config, pkgs, ... }:

{
  imports = [ ../../services/nginx-phpfpm.nix ];

  networking.firewall.enable = false;

  services.journald.extraConfig = "SystemMaxUse=500M";

  services.nginx.enable = true;
  services.nginx.virtualHosts = {
    "uzbl.org".globalRedirect = "www.uzbl.org";

    "www.uzbl.org" = {
      root = "/srv/http/www";
      locations."= /archives.php".extraConfig    = "rewrite ^(.*) /index.php;";
      locations."= /faq.php".extraConfig         = "rewrite ^(.*) /index.php;";
      locations."= /readme.php".extraConfig      = "rewrite ^(.*) /index.php;";
      locations."= /keybindings.php".extraConfig = "rewrite ^(.*) /index.php;";
      locations."= /get.php".extraConfig         = "rewrite ^(.*) /index.php;";
      locations."= /community.php".extraConfig   = "rewrite ^(.*) /index.php;";
      locations."= /contribute.php".extraConfig  = "rewrite ^(.*) /index.php;";
      locations."= /commits.php".extraConfig     = "rewrite ^(.*) /index.php;";
      locations."= /news.php".extraConfig        = "rewrite ^(.*) /index.php;";
      locations."/doesitwork/".extraConfig       = "rewrite ^(.*) /index.php;";
      locations."/fosdem2010/".extraConfig       = "rewrite ^(.*) /index.php;";
      locations."/wiki/".tryFiles = "$uri $uri/ @dokuwiki";
      locations."~ /wiki/(data/|conf/|bin/|inc/|install.php)".extraConfig = "deny all;";
      locations."@dokuwiki".extraConfig = ''
        rewrite ^/wiki/_media/(.*) /wiki/lib/exe/fetch.php?media=$1 last;
        rewrite ^/wiki/_detail/(.*) /wiki/lib/exe/detail.php?media=$1 last;
        rewrite ^/wiki/_export/([^/]+)/(.*) /wiki/doku.php?do=export_$1&id=$2 last;
        rewrite ^/wiki/(.*) /wiki/doku.php?id=$1&$args last;
      '';
      locations."~ \.php$".extraConfig = ''
        include ${pkgs.nginx}/conf/fastcgi_params;
        fastcgi_pass  unix:/run/phpfpm/phpfpm.sock;
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME $document_root/$fastcgi_script_name;
      '';
      extraConfig = ''
        index index.php;
        access_log /dev/null;
        error_log  /var/spool/nginx/logs/www.error.log;
      '';
    };
  };

  services.logrotate.enable = true;
  services.logrotate.config = ''
/var/spool/nginx/logs/www.error.log {
    weekly
    copytruncate
    rotate 1
    compress
    postrotate
        systemctl kill nginx.service --signal=USR1
    endscript
}
  '';

  systemd.services.git-pull-www =
    { enable   = true
    ; script = "exec ${pkgs.git}/bin/git pull"
    ; startAt = "hourly"
    ; serviceConfig.WorkingDirectory = "/srv/http/www"
    ; };

  systemd.services.git-pull-uzbl =
    { enable   = true
    ; script = "exec ${pkgs.git}/bin/git pull"
    ; startAt = "hourly"
    ; serviceConfig.WorkingDirectory = "/srv/http/uzbl"
    ; };

  environment.systemPackages = [ pkgs.git ];
}
