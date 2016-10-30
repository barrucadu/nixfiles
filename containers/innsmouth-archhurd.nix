{ config, pkgs, ... }:

let
  vHost = { subdomain, config ? "", webdir ? "${subdomain}" }:
    { hostname = "${subdomain}.archhurd.org"
    ; webdir   = webdir
    ; config   = config
    ; };

  phpSite = { subdomain, config ? "", webdir ? "${subdomain}" }:
    { subdomain = subdomain
    ; webdir    = webdir
    ; config    = ''
      index index.html index.htm index.php;

      location ~ \.php$ {
        include ${pkgs.nginx}/conf/fastcgi_params;
        fastcgi_pass  unix:/run/phpfpm/phpfpm.sock;
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME $document_root/$fastcgi_script_name;
      }

      ${config}
      ''
    ; };
in
{
  imports =
    [ ../services/nginx.nix
      ../services/vsftpd.nix
    ];

  networking.firewall.enable = false;

  # Web
  services.nginx.enable    = true;
  services.nginx.enablePHP = true;
  services.nginx.enableSSL = false;

  services.nginx.hosts = map vHost
    [ { subdomain = "www"
      ; config    = ''
        location / {
          proxy_read_timeout 300;
          proxy_connect_timeout 300;
          proxy_pass http://127.0.0.1:8000;
        }

        location /static {
          rewrite /static(.*) /$1 break;
          root /srv/archweb/archweb/collected_static;
        }

        location /media { root /srv/archweb/; }
      ''
      ; }

      (phpSite { subdomain = "aur"
                ; webdir   = "aur/web/html"
                ; config   = ''
                  location /packages/ {
                    autoindex on;
                    rewrite /packages/(.*) /$1 break;
                    root /srv/http/aur/unsupported;
                  }
                ''
                ; }
      )

      (phpSite { subdomain = "bugs"; })

      { subdomain = "files"
      ; config    = "location / { autoindex on; }"
      ; }

      { subdomain = "lists"; }


      (phpSite { subdomain = "wiki"
                ; config   = ''
                  location /wiki {
                    index index.php;
                    rewrite ^/wiki/(.*)$ /index.php?title=$1&$args;
                  }

                  location /maintenance/ { return 403; }
                  location ^~ /cache/    { deny all;   }
                ''
                ; }
      )
    ];

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

  # Extra packages
  environment.systemPackages = [ pkgs.python2Packages.virtualenv ];
}
