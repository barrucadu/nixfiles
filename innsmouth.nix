{ config, pkgs, lib, ... }:

with lib;

let
  acmedir = "/var/acme-challenges";

  acmeconf = ''
    location '/.well-known/acme-challenge' {
      default_type "text/plain";
      root ${acmedir};
    }
  '';

  vHost = { domain, subdomain ? "www", config ? "", webdir ? "${domain}/${subdomain}" }:
    { hostname = "${subdomain}.${domain}"
    ; certname = domain
    ; webdir = webdir
    ; config = config
    ; };

  phpSite = { domain, subdomain ? "www", config ? "", webdir ? "${domain}/${subdomain}" }:
    { domain = domain
    ; subdomain = subdomain
    ; webdir = webdir
    ; config = ''
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

  wwwRedirect = domain:
    { hostname = domain
    ; certname = domain
    ; to = "https://www.${domain}"
    ; config = acmeconf
    ; httpAlso = true
    ; };

  cert = extras:
    { webroot = acmedir
    ; extraDomains = genAttrs extras (name: null)
    ; email = "mike@barrucadu.co.uk"
    ; user = "nginx"
    ; group = "nginx"
    ; allowKeysForGroup = true
    ; };

  container = num: config:
    { autoStart      = true
    ; privateNetwork = true
    ; hostAddress    = "192.168.254.${toString num}"
    ; localAddress   = "192.168.255.${toString num}"
    ; config         = config
    ; };
in

{
  networking.hostName = "innsmouth";

  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix

      # Include the standard configuration.
      ./base/default.nix

      # Include other configuration.
      ./services/nginx.nix
      ./services/openssh.nix
      ./services/vsftpd.nix
    ];

  # Bootloader
  boot.loader.grub.enable  = true;
  boot.loader.grub.version = 2;
  boot.loader.grub.device  = "/dev/sda";

  # Use the serial console (required for lish)
  boot.kernelParams = [ "console=ttyS0" ];
  boot.loader.grub.extraConfig = "serial; terminal_input serial; terminal_output serial";

  # Open a bunch of ports and forward some stuff
  boot.kernel.sysctl."net.ipv4.ip_forward" = true;
  networking.firewall.allowPing = true;
  networking.firewall.allowedTCPPorts = [ 21 70 80 443 873 ];
  networking.firewall.allowedUDPPortRanges = [ { from = 60000; to = 61000; } ];
  networking.firewall.extraCommands = ''
    iptables -t nat -A PREROUTING -i enp0s4 -p tcp --dport 70 -j DNAT --to 192.168.255.2:70
  '';

  # Container configuration
  containers.archhurd  = container 1 (import ./containers/innsmouth-archhurd.nix);
  containers.barrucadu = container 2 (import ./containers/innsmouth-barrucadu.nix);
  containers.mawalker  = container 3 (import ./containers/innsmouth-mawalker.nix);
  containers.uzbl      = container 4 (import ./containers/innsmouth-uzbl.nix);

  # Web server
  services.nginx.enablePHP = true;

  services.nginx.extraConfig = ''
    server {
      listen  443       ssl  spdy;
      listen  [::]:443  ssl  spdy;

      server_name  barrucadu.co.uk, *.barrucadu.co.uk;

      ssl_certificate      ${config.security.acme.directory}/barrucadu.co.uk/fullchain.pem;
      ssl_certificate_key  ${config.security.acme.directory}/barrucadu.co.uk/key.pem;

      location / {
        proxy_pass        http://192.168.255.2;
        proxy_redirect    off;
        proxy_set_header  Host             $host;
        proxy_set_header  X-Real-IP        $remote_addr;
        proxy_set_header  X-Forwarded-For  $proxy_add_x_forwarded_for;
      }
    }

    server {
      listen  443       ssl  spdy;
      listen  [::]:443  ssl  spdy;

      server_name  mawalker.me.uk, *.mawalker.me.uk;

      ssl_certificate      ${config.security.acme.directory}/mawalker.me.uk/fullchain.pem;
      ssl_certificate_key  ${config.security.acme.directory}/mawalker.me.uk/key.pem;

      location / {
        proxy_pass        http://192.168.255.3;
        proxy_redirect    off;
        proxy_set_header  Host             $host;
        proxy_set_header  X-Real-IP        $remote_addr;
        proxy_set_header  X-Forwarded-For  $proxy_add_x_forwarded_for;
      }
    }
  '';

  services.nginx.hosts = map vHost
    [ { domain = "archhurd.org"
      ; config = ''
        location / {
          proxy_read_timeout 300;
          proxy_connect_timeout 300;
          proxy_pass http://127.0.0.1:8000;
        }

        location /static {
          rewrite /static(.*) /$1 break;
          root /srv/http/archhurd.org/www/archweb/collected_static;
        }

        location /media { root /srv/http/archhurd.org/www; }
      ''
      ; }

      (phpSite { domain = "archhurd.org"
                ; subdomain = "aur"
                ; webdir = "archhurd.org/aur/web/html"
                ; config = ''
                  location /packages/ {
                    autoindex on;
                    rewrite /packages/(.*) /$1 break;
                    root /srv/http/archhurd.org/aur/unsupported;
                  }
                ''
                ; }
      )

      (phpSite { domain = "archhurd.org"; subdomain = "bugs"; })

      { domain = "archhurd.org"
      ; subdomain = "files"
      ; config = "location / { autoindex on; }"
      ; }

      { domain = "archhurd.org"; subdomain = "lists"; }


      (phpSite { domain = "archhurd.org"
                ; subdomain = "wiki"
                ; config = ''
                  location /wiki {
                    index index.php;
                    rewrite ^/wiki/(.*)$ /index.php?title=$1&$args;
                  }

                  location /maintenance/ { return 403; }
                  location ^~ /cache/    { deny all;   }
                ''
                ; }
      )

      (phpSite { domain = "uzbl.org"
               ; config = ''
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
               ''
               ; }
      )
    ];

  services.nginx.redirects =
    [ # Redirect http{s,}://foo to https://www.foo
      (wwwRedirect "barrucadu.co.uk")
      (wwwRedirect "mawalker.me.uk")
      (wwwRedirect "archhurd.org")
      (wwwRedirect "uzbl.org")

      # Redirect barrucadu.com to barrucadu.co.uk
      { hostname = "barrucadu.com"
      ; certname = "barrucadu.com"
      ; to = "https://www.barrucadu.co.uk"
      ; config = acmeconf
      ; httpAlso = true
      ; }

      # Redirects http to https
      { hostname = "docs.barrucadu.co.uk"; config = acmeconf; }
      { hostname = "go.barrucadu.co.uk";   config = acmeconf; }
      { hostname = "misc.barrucadu.co.uk"; config = acmeconf; }
      { hostname = "wiki.barrucadu.co.uk"; config = acmeconf; }
      { hostname = "aur.archhurd.org";     config = acmeconf; }
      { hostname = "bugs.archhurd.org";    config = acmeconf; }
      { hostname = "files.archhurd.org";   config = acmeconf; }
      { hostname = "lists.archhurd.org";   config = acmeconf; }
      { hostname = "wiki.archhurd.org";    config = acmeconf; }
    ];

  # SSL certificates
  security.acme.certs =
    { "barrucadu.co.uk" = cert [ "www.barrucadu.co.uk" "docs.barrucadu.co.uk" "go.barrucadu.co.uk" "misc.barrucadu.co.uk" "wiki.barrucadu.co.uk" ]
    ; "barrucadu.com"   = cert [ "www.barrucadu.com" ]
    ; "mawalker.me.uk"  = cert [ "www.mawalker.me.uk" ]
    ; "archhurd.org"    = cert [ "www.archhurd.org" "aur.archhurd.org" "bugs.archhurd.org" "files.archhurd.org" "lists.archhurd.org" "wiki.archhurd.org" ]
    ; "uzbl.org"        = cert [ "www.uzbl.org" ]
    ; };

  # Databases
  services.mysql =
    { enable  = true
    ; package = pkgs.mysql
    ; };

  services.mongodb =
    { enable = true
    ; };

  services.postgresql =
    { enable = true
    ; package = pkgs.postgresql95
    ; };

  # Gitolite
  services.gitolite =
    { enable = true
    ; user = "git"
    ; dataDir = "/srv/git"
    ; adminPubkey = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDILnZ0gRTqD6QnPMs99717N+j00IEESLRYQJ33bJ8mn8kjfStwFYFhXvnVg7iLV1toJ/AeSV9jkCY/nVSSA00n2gg82jNPyNtKl5LJG7T5gCD+QaIbrJ7Vzc90wJ2CVHOE9Yk+2lpEWMRdCBLRa38fp3/XCapXnt++ej71WOP3YjweB45RATM30vjoZvgw4w486OOqhoCcBlqtiZ47oKTZZ7I2VcFJA0pzx2sbArDlWZwmyA4C0d+kQLH2+rAcoId8R6CE/8gsMUp8xdjg5r0ZxETKwhlwWaMxICcowDniExFQkBo98VbpdE/5BfAUDj4fZLgs/WRGXZwYWRCtJfrL barrucadu@azathoth"
    ; };

  # FTP daemon
  services.barrucadu-vsftpd =
    { enable = true
    ; anonymousUser = true
    ; anonymousUserNoPassword = true
    ; anonymousUserHome = "/srv/ftp"
    ; };

  # rsync daemon
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
  environment.systemPackages = with pkgs; [
    irssi
    perl
    (texlive.combine
      { inherit (texlive) scheme-medium; })
  ];
}
