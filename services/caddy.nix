{ config, lib, ... }:

{
  options = {
    services.caddy.enable-phpfpm-pool = lib.mkOption { default = false; };
  };

  config = {
    services.caddy.enable = true;
    services.caddy.agree = true;
    services.caddy.email = "mike@barrucadu.co.uk";

    services.phpfpm = lib.mkIf config.services.caddy.enable-phpfpm-pool {
      pools.caddy = {
        user = "caddy";
        group = "caddy";
        settings = {
          "listen" = "/run/phpfpm/caddy.sock";
          "listen.owner" = "caddy";
          "listen.group" = "caddy";
          "pm" = "dynamic";
          "pm.max_children" = "5";
          "pm.start_servers" = "2";
          "pm.min_spare_servers" = "1";
          "pm.max_spare_servers" = "3";
        };
      };
    };
  };
}
