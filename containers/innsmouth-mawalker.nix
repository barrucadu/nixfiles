{ config, pkgs, ... }:

{
  imports = [ ../services/nginx.nix ];

  networking.firewall.enable = false;

  services.nginx.enable    = true;
  services.nginx.enablePHP = true;
  services.nginx.enableSSL = false;
  services.nginx.hosts     =
    [ { hostname = "www.mawalker.me.uk"
      ; webdir   = "www"
      ; config   = ''
        index index.html index.htm index.php;

        location ~ \.php$ {
          include ${pkgs.nginx}/conf/fastcgi_params;
          fastcgi_pass  unix:/run/phpfpm/phpfpm.sock;
          fastcgi_index index.php;
          fastcgi_param SCRIPT_FILENAME $document_root/$fastcgi_script_name;
        }
        ''
      ; }
    ];
}
