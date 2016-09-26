{ config, pkgs, ... }:

{
  imports = [ ../services/nginx.nix ];

  networking.firewall.enable = false;

  services.nginx.enable    = true;
  services.nginx.enablePHP = true;
  services.nginx.enableSSL = false;
  services.nginx.hosts     =
    [ { hostname = "www.uzbl.org"
      ; webdir   = "www"
      ; config = ''
        index index.html index.htm index.php;

        location = /archives.php    { rewrite ^(.*) /index.php; }
        location = /faq.php         { rewrite ^(.*) /index.php; }
        location = /readme.php      { rewrite ^(.*) /index.php; }
        location = /keybindings.php { rewrite ^(.*) /index.php; }
        location = /get.php         { rewrite ^(.*) /index.php; }
        location = /community.php   { rewrite ^(.*) /index.php; }
        location = /contribute.php  { rewrite ^(.*) /index.php; }
        location = /commits.php     { rewrite ^(.*) /index.php; }
        location = /news.php        { rewrite ^(.*) /index.php; }
        location /doesitwork/       { rewrite ^(.*) /index.php; }
        location /fosdem2010/       { rewrite ^(.*) /index.php; }

        location /wiki/ { try_files $uri $uri/ @dokuwiki; }
        location ~ /wiki/(data/|conf/|bin/|inc/|install.php) { deny all; }
        location @dokuwiki {
          rewrite ^/wiki/_media/(.*) /wiki/lib/exe/fetch.php?media=$1 last;
          rewrite ^/wiki/_detail/(.*) /wiki/lib/exe/detail.php?media=$1 last;
          rewrite ^/wiki/_export/([^/]+)/(.*) /wiki/doku.php?do=export_$1&id=$2 last;
          rewrite ^/wiki/(.*) /wiki/doku.php?id=$1&$args last;
        }

        location ~ \.php$ {
          include ${pkgs.nginx}/conf/fastcgi_params;
          fastcgi_pass  unix:/run/phpfpm/phpfpm.sock;
          fastcgi_index index.php;
          fastcgi_param SCRIPT_FILENAME $document_root/$fastcgi_script_name;
        }
      ''
      ; }
    ];

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
