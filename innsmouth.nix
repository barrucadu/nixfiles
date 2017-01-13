{ config, pkgs, lib, ... }:

with lib;

let
  # CONTAINERS
  # ==========
  #
  # Just edit this attribute set. Everything else maps over it, so
  # this should be all you need to touch.
  containerSpecs =
    { archhurd  = { num = 1; config = (import ./containers/innsmouth-archhurd.nix);  domain = "archhurd.org";    extrasubs = ["aur" "bugs" "files" "lists" "wiki"]; ports = [21 873];}
    ; barrucadu = { num = 2; config = (import ./containers/innsmouth-barrucadu.nix); domain = "barrucadu.co.uk"; extrasubs = ["docs" "go" "misc" "wiki"]; ports = [70];}
    ; mawalker  = { num = 3; config = (import ./containers/innsmouth-mawalker.nix);  domain = "mawalker.me.uk";  extrasubs = []; ports = []; }
    ; uzbl      = { num = 4; config = (import ./containers/innsmouth-uzbl.nix);      domain = "uzbl.org";        extrasubs = []; ports = []; }
    ; };
  containerSpecs' = mapAttrsToList (k: v: v) containerSpecs;

  acmedir = "/var/acme-challenges";

  acmeconf = ''
    location '/.well-known/acme-challenge' {
      default_type "text/plain";
      root ${acmedir};
    }
  '';

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
      ./services/syncthing.nix
    ];

  # Bootloader
  boot.loader.grub.enable  = true;
  boot.loader.grub.version = 2;
  boot.loader.grub.device  = "/dev/sda";

  # Use the serial console (required for lish)
  boot.kernelParams = [ "console=ttyS0" ];
  boot.loader.grub.extraConfig = "serial; terminal_input serial; terminal_output serial";

  # Firewall and container NAT
  networking.firewall.allowPing = true;
  networking.firewall.allowedTCPPorts = [ 21 70 80 443 873 ];
  networking.firewall.allowedUDPPortRanges = [ { from = 60000; to = 61000; } ];

  networking.nat.enable = true;
  networking.nat.internalInterfaces = ["ve-+"];
  networking.nat.externalInterface = "enp0s4";
  networking.nat.forwardPorts = concatMap
    ( {num, ports, ...}:
        map (p: { sourcePort = p; destination = "192.168.255.${toString num}:${toString p}"; }) ports
    ) containerSpecs';

  # Container configuration
  containers = mapAttrs
    (_: {num, config, ...}:
      { autoStart      = true
      ; privateNetwork = true
      ; hostAddress    = "192.168.254.${toString num}"
      ; localAddress   = "192.168.255.${toString num}"
      ; config         = config
      ; }
    ) containerSpecs;

  # Web server
  services.nginx.extraConfig = concatMapStringsSep "\n"
    ({num, domain, extrasubs, ...}: ''
      server {
        listen  443       ssl  http2;
        listen  [::]:443  ssl  http2;

        server_name  ${concatMapStringsSep "  " (sub: "${sub}.${domain}") (["www"] ++ extrasubs)};

        ssl_certificate      ${config.security.acme.directory}/${domain}/fullchain.pem;
        ssl_certificate_key  ${config.security.acme.directory}/${domain}/key.pem;

        location / {
          proxy_pass        http://192.168.255.${toString num};
          proxy_redirect    off;
          proxy_set_header  Host             $host;
          proxy_set_header  X-Real-IP        $remote_addr;
          proxy_set_header  X-Forwarded-For  $proxy_add_x_forwarded_for;
        }
      }
      ''
    ) containerSpecs';

  services.nginx.redirects =
    [ # Redirect barrucadu.com to www.barrucadu.co.uk
      { hostname = ".barrucadu.com"
      ; certname = "barrucadu.com"
      ; to = "https://www.barrucadu.co.uk"
      ; config = acmeconf
      ; http = true
      ; https = true
      ; }
    ] ++ concatMap
    ({domain, extrasubs, ...}:
      [ { hostname = domain
        ; certname = domain
        ; to       = "https://www.${domain}"
        ; config   = acmeconf
        ; http     = true
        ; https    = true
        ; }
      ] ++
      map (sub: { hostname = "${sub}.${domain}"
                ; to       = "https://${sub}.${domain}"
                ; config   = acmeconf
                ; http     = true
                ; }
          ) (["www"] ++ extrasubs)
    ) containerSpecs';

  # SSL certificates
  security.acme.certs = mapAttrs'
    (_: {domain, extrasubs, ...}: nameValuePair domain
      { webroot = acmedir
      ; extraDomains = genAttrs (map (subdomain: "${subdomain}.${domain}") (["www"] ++ extrasubs)) (name: null)
      ; email = "mike@barrucadu.co.uk"
      ; user = "nginx"
      ; group = "nginx"
      ; allowKeysForGroup = true
      ; }
    ) containerSpecs;

  # Databases
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
