{ config, pkgs, ... }:

{
  imports = [ ../../services/nginx-phpfpm.nix ];

  networking.firewall.enable = false;

  services.nginx.enable = true;
  services.nginx.virtualHosts = {
    "www.mawalker.me.uk" = {
      root = "/srv/http/www";
      locations."~ \.php$".extraConfig = ''
        include ${pkgs.nginx}/conf/fastcgi_params;
        fastcgi_pass  unix:/run/phpfpm/phpfpm.sock;
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME $document_root/$fastcgi_script_name;
      '';
      extraConfig = ''
        index index.php;
        access_log /var/spool/nginx/logs/www.access.log;
        error_log  /var/spool/nginx/logs/www.error.log;
      '';
    };
  };
}
