{ config, pkgs, ... }:

let
  vHost = { subdomain, config ? "" }:
    { hostname = "${subdomain}.barrucadu.co.uk"
    ; webdir   = subdomain
    ; config   = config
    ; };
  alias   = from: to: "location ${from} { alias ${to}; }";
  expires = regex: when: "location ~* ${regex} { expires ${when}; }";
in
{
  imports = [ ../services/nginx.nix ];

  networking.firewall.enable = false;

  services.nginx.enable    = true;
  services.nginx.enableSSL = false;
  services.nginx.hosts     = map vHost
    [ { subdomain = "www"
      ; config    = ''
        ${alias "/bookdb/covers/" "/srv/bookdb/covers/"}
        ${alias "= /bookdb/script.js" "/srv/bookdb/script.js"}
        ${alias "= /bookdb/style.css" "/srv/bookdb/style.css"}

        location /bookdb/ {
          proxy_set_header Host $host;
          proxy_set_header X-Real-IP $remote_addr;
          proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
          proxy_set_header X-Forwarded-Proto $scheme;

          proxy_read_timeout 300;
          proxy_connect_timeout 300;
          proxy_pass http://127.0.0.1:3000;
        }

        ${expires "index\.html$" "7d"}
        ${expires "\.html$" "30d"}
        ${expires "(cv.pdf|robots.txt|style.css)$" "30d"}
        ${expires "(fonts|postfiles|publications)" "365d"}
      ''
      ; }

      { subdomain = "docs"
      ; config    = ''
      # Serve .go files as HTML, for godoc.
      include ${pkgs.nginx}/conf/mime.types;
      types {
        text/html go;
      }
      ''
      ; }

      { subdomain = "go"
      ; config    = "include ${config.services.nginx.webroot}/go.conf;"
      ; }

      { subdomain = "misc"
      ; config    = "location /pub/ { autoindex on; }"
      ; }

      { subdomain = "wiki"
      ; }
    ];

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
}
