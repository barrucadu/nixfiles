{ config, pkgs, lib, ... }:

with lib;

let
  # CONTAINERS
  # ==========
  #
  # Just edit this attribute set. Everything else maps over it, so
  # this should be all you need to touch.
  containerSpecs =
    { archhurd  = { num = 1; config = (import ./hosts/innsmouth/archhurd.nix);  domain = "archhurd.org";    extrasubs = ["aur" "bugs" "files" "lists" "wiki"]; ports = [21 873];}
    ; barrucadu = { num = 2; config = (import ./hosts/innsmouth/barrucadu.nix); domain = "barrucadu.co.uk"; extrasubs = ["ci" "docs" "go" "memo" "misc"]; ports = [70];}
    ; mawalker  = { num = 3; config = (import ./hosts/innsmouth/mawalker.nix);  domain = "mawalker.me.uk";  extrasubs = []; ports = []; }
    ; uzbl      = { num = 4; config = (import ./hosts/innsmouth/uzbl.nix);      domain = "uzbl.org";        extrasubs = []; ports = []; }
    ; };
  containerSpecs' = mapAttrsToList (k: v: v) containerSpecs;
in
{
  networking.hostName = "innsmouth";

  imports = [
    ./common.nix
    ./hardware-configuration.nix
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
  networking.firewall.allowedTCPPorts = [ 80 443 ] ++ concatMap ({ports, ...}: ports) containerSpecs';
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
  services.nginx.enable = true;
  services.nginx.package = pkgs.nginx;
  services.nginx.recommendedGzipSettings  = true;
  services.nginx.recommendedOptimisation  = true;
  services.nginx.recommendedProxySettings = true;
  services.nginx.recommendedTlsSettings   = true;
  services.nginx.commonHttpConfig = ''
    log_format combined_vhost '$host '
                              '$remote_addr - $remote_user [$time_local] '
                              '"$request" $status $body_bytes_sent '
                              '"$http_referer" "$http_user_agent"';
    access_log logs/access.log combined_vhost;
  '';
  services.nginx.virtualHosts = mkMerge
    [ { default = { default = true; locations."/".root = "/srv/http/"; }; }
      (mapAttrs'
        (_: {num, domain, extrasubs, ...}:
          let cfg = {
                serverAliases = map (sub: "${sub}.${domain}") (["www"]++extrasubs);
                enableACME = true;
                forceSSL   = true;
                locations."/".proxyPass = "http://192.168.255.${toString num}";
                extraConfig = ''
                  header_filter_by_lua_block {
                    if not ngx.header["Content-Security-Policy"] then ngx.header["Content-Security-Policy"] = "default-src 'self'; script-src 'self' 'unsafe-inline' 'unsafe-eval'; style-src 'self' 'unsafe-inline'; font-src 'self' https://fonts.gstatic.com" end
                    if not ngx.header["Referrer-Policy"] then ngx.header["Referrer-Policy"] = "strict-origin-when-cross-origin" end
                    if not ngx.header["Strict-Transport-Security"] then ngx.header["Strict-Transport-Security"] = "max-age=31536000; includeSubDomains" end
                    if not ngx.header["X-Content-Type-Options"] then ngx.header["X-Content-Type-Options"] = "nosniff" end
                    if not ngx.header["X-Frame-Options"] then ngx.header["X-Frame-Options"] = "SAMEORIGIN" end
                    if not ngx.header["X-XSS-Protection"] then ngx.header["X-XSS-Protection"] = "1; mode=block" end
                  }
                '';
              };
          in nameValuePair "${domain}" cfg)
        containerSpecs)
    ];

  # Databases
  services.mongodb.enable = true;
  # Gitolite
  services.gitolite =
    { enable = true
    ; user = "git"
    ; dataDir = "/srv/git"
    ; adminPubkey = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDILnZ0gRTqD6QnPMs99717N+j00IEESLRYQJ33bJ8mn8kjfStwFYFhXvnVg7iLV1toJ/AeSV9jkCY/nVSSA00n2gg82jNPyNtKl5LJG7T5gCD+QaIbrJ7Vzc90wJ2CVHOE9Yk+2lpEWMRdCBLRa38fp3/XCapXnt++ej71WOP3YjweB45RATM30vjoZvgw4w486OOqhoCcBlqtiZ47oKTZZ7I2VcFJA0pzx2sbArDlWZwmyA4C0d+kQLH2+rAcoId8R6CE/8gsMUp8xdjg5r0ZxETKwhlwWaMxICcowDniExFQkBo98VbpdE/5BfAUDj4fZLgs/WRGXZwYWRCtJfrL barrucadu@azathoth"
    ; };

  # Log files
  services.logrotate.enable = true;
  services.logrotate.config = ''
/var/spool/nginx/logs/access.log /var/spool/nginx/logs/error.log {
    weekly
    copytruncate
    rotate 4
    compress
    postrotate
        systemctl kill nginx.service --signal=USR1
    endscript
}
  '';

  nixpkgs.config.packageOverrides = pkgs: {
    # Build nginx with lua support.
    nginx = pkgs.nginx.override { modules = [ pkgs.nginxModules.lua ]; };
  };

  # Extra packages
  environment.systemPackages = with pkgs; [
    irssi
    perl
    texlive.combined.scheme-full
  ];
}
