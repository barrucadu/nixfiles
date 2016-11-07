{ config, ... }:

{
  networking.firewall =
    { allowedTCPPorts = [ 22000 ]
    ; allowedUDPPorts = [ 21027 ]
    ; };

  services.syncthing =
    { enable     = true
    ; useInotify = true
    ; user       = "barrucadu"
    ; } ;
}
