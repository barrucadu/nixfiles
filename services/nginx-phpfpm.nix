{ config, ... }:

{
  services.phpfpm.pools.nginx = {
    user = "nginx";
    group = "nginx";
    settings = {
      "listen" = "/run/phpfpm/phpfpm.sock";
      "listen.owner" = "nginx";
      "listen.group" = "nginx";
      "pm" = "dynamic";
      "pm.max_children" = "5";
      "pm.start_servers" = "2";
      "pm.min_spare_servers" = "1";
      "pm.max_spare_servers" = "3";
    };
  };
}
