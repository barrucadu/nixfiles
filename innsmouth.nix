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

  vHost = { domain, subdomain ? "www", config ? "" }:
    { hostname = "${subdomain}.${domain}"
    ; certname = domain
    ; webdir = "${domain}/${subdomain}"
    ; config = config
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
    ];

  # Use the serial console (required for lish)
  boot.kernelParams = [ "console=ttyS0" ];
  boot.loader.grub.extraConfig = "serial; terminal_input serial; terminal_output serial";

  # Open a bunch of ports
  networking.firewall.allowPing = true;
  networking.firewall.allowedTCPPorts = [ 80 443 ];
  networking.firewall.allowedUDPPortRanges = [ { from = 60000; to = 61000; } ];

  # Web server
  services.nginx.enablePHP = true;
  services.phpfpm.phpIni = "/etc/nixos/php.ini";

  services.nginx.hosts = map vHost
    [ { domain = "barrucadu.co.uk"
      ; config = ''
        location = /bookdb/style.css {
          alias /srv/http/barrucadu.co.uk/bookdb/static/style.css;
        }
        location = /bookdb/script.js {
          alias /srv/http/barrucadu.co.uk/bookdb/static/script.js;
        }
        location /bookdb/covers/ {
          alias /srv/http/barrucadu.co.uk/bookdb/covers/;
        }

        location /bookdb/ {
          proxy_set_header Host $host;
          proxy_set_header X-Real-IP $remote_addr;
          proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
          proxy_set_header X-Forwarded-Proto $scheme;

          proxy_read_timeout 300;
          proxy_connect_timeout 300;
          proxy_pass http://127.0.0.1:3000;
        }

        location ~* index\.html$ {
          expires 7d;
        }
        location ~* \.html$ {
          expires 30d;
        }
        location ~* (cv.pdf|robots.txt|style.css)$ {
          expires 30d;
        }
        location ~* (fonts|postfiles|publications) {
          expires 365d;
        }
      ''
      ; }

      { domain = "barrucadu.co.uk"
      ; subdomain = "docs"
      ; }

      { domain = "barrucadu.co.uk"
      ; subdomain = "go"
      ; config = "include ${config.services.nginx.webroot}/barrucadu.co.uk/go.conf;"
      ; }

      { domain = "barrucadu.co.uk"
      ; subdomain = "misc"
      ; config = "location /pub/ { autoindex on; }"
      ; }

      { domain = "mawalker.me.uk"
      ; config = ''
        index index.html index.htm index.php;

        location ~ \.php$ {
	  include ${pkgs.nginx}/conf/fastcgi_params;
          fastcgi_pass  unix:/run/php-fpm/php-fpm.sock;
          fastcgi_index index.php;
          fastcgi_param SCRIPT_FILENAME $document_root/$fastcgi_script_name;
        }
      ''
      ; }
    ];

  services.nginx.redirects =
    [ # Redirect http{s,}://foo to https://www.foo
      (wwwRedirect "barrucadu.co.uk")
      (wwwRedirect "mawalker.me.uk")

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
    ];

  # SSL certificates
  security.acme.certs =
    { "barrucadu.co.uk" = cert [ "www.barrucadu.co.uk" "docs.barrucadu.co.uk" "go.barrucadu.co.uk" "misc.barrucadu.co.uk" ]
    ; "barrucadu.com"   = cert [ "www.barrucadu.com" ]
    ; "mawalker.me.uk"  = cert [ "www.mawalker.me.uk" ]
    ; };

  # Databases
  services.mysql =
  { enable  = true
  ; package = pkgs.mysql
  ; };

  services.mongodb =
  { enable = true
  ; };

  # Gitolite
  services.gitolite =
    { enable = true
    ; user = "git"
    ; dataDir = "/srv/git"
    ; adminPubkey = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDILnZ0gRTqD6QnPMs99717N+j00IEESLRYQJ33bJ8mn8kjfStwFYFhXvnVg7iLV1toJ/AeSV9jkCY/nVSSA00n2gg82jNPyNtKl5LJG7T5gCD+QaIbrJ7Vzc90wJ2CVHOE9Yk+2lpEWMRdCBLRa38fp3/XCapXnt++ej71WOP3YjweB45RATM30vjoZvgw4w486OOqhoCcBlqtiZ47oKTZZ7I2VcFJA0pzx2sbArDlWZwmyA4C0d+kQLH2+rAcoId8R6CE/8gsMUp8xdjg5r0ZxETKwhlwWaMxICcowDniExFQkBo98VbpdE/5BfAUDj4fZLgs/WRGXZwYWRCtJfrL barrucadu@azathoth"
    ; };

  # Extra packages
  environment.systemPackages = with pkgs; [
    irssi
    perl
    (texlive.combine
      { inherit (texlive) scheme-medium; })
  ];
}
