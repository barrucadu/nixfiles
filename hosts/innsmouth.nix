{ config, pkgs, lib, ... }:

with lib;

let
  # CONTAINERS
  # ==========
  #
  # Just edit this attribute set. Everything else maps over it, so
  # this should be all you need to touch.
  containerSpecs =
    { barrucadu = { num = 2; config = (import ./hosts/innsmouth/barrucadu.nix); domain = "barrucadu.co.uk"; extrasubs = ["memo" "misc"];}
    ; mawalker  = { num = 3; config = (import ./hosts/innsmouth/mawalker.nix);  domain = "mawalker.me.uk";  extrasubs = []; }
    ; uzbl      = { num = 4; config = (import ./hosts/innsmouth/uzbl.nix);      domain = "uzbl.org";        extrasubs = []; }
    ; };
in
{
  networking.hostName = "innsmouth";

  imports = [
    ./common.nix
    ./hardware-configuration.nix
    ./services/nginx.nix
  ];

  # Bootloader
  boot.loader.grub.enable  = true;
  boot.loader.grub.version = 2;
  boot.loader.grub.device  = "/dev/sda";

  # Use the serial console (required for lish)
  boot.kernelParams = [ "console=ttyS0" ];
  boot.loader.grub.extraConfig = "serial; terminal_input serial; terminal_output serial";

  # Firewall and container NAT
  networking.firewall.allowedTCPPorts = [ 80 443 ];
  networking.firewall.allowedUDPPortRanges = [ { from = 60000; to = 61000; } ];

  networking.nat.enable = true;
  networking.nat.internalInterfaces = ["ve-+"];
  networking.nat.externalInterface = "ens4";

  # Container configuration
  containers = mapAttrs
    (_: {num, config, ...}:
      { autoStart      = true
      ; privateNetwork = true
      ; hostAddress    = "192.168.254.${toString num}"
      ; localAddress   = "192.168.255.${toString num}"
      ; forwardPorts   = []
      ; config         = config
      ; }
    ) containerSpecs;

  # Web server
  services.nginx.commonHttpConfig = ''
    log_format combined_vhost '$host '
                              '$remote_addr - $remote_user [$time_local] '
                              '"$request" $status $body_bytes_sent '
                              '"$http_referer" "$http_user_agent"';
    access_log logs/access.log combined_vhost;
  '';
  services.nginx.virtualHosts = mkMerge
    [ { default = { default = true; locations."/".root = "/srv/http/"; }; }
      { "barrucadu.com" = { serverAliases = [ "www.barrucadu.com" ]; locations."/".extraConfig = "return 301 https://www.barrucadu.co.uk$request_uri;"; enableACME = true; }; }
      { "barrucadu.uk"  = { serverAliases = [ "www.barrucadu.uk"  ]; locations."/".extraConfig = "return 301 https://www.barrucadu.co.uk$request_uri;"; enableACME = true; }; }
      { "ci.barrucadu.co.uk" = { enableACME = true; forceSSL = true; locations."/".proxyPass = "http://127.0.0.1:${toString config.services.jenkins.port}"; }; }
      (mapAttrs'
        (_: {num, domain, extrasubs, ...}:
          let cfg = {
                serverAliases = map (sub: "${sub}.${domain}") (["www"]++extrasubs);
                enableACME = true;
                forceSSL   = true;
                locations."/".proxyPass = "http://192.168.255.${toString num}";
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

  # CI
  services.jenkins.enable = true;
  services.jenkins.port = 3001;
  services.jenkins.packages = with pkgs;
    let env = buildEnv
      { name = "jenkins-env"
      ; pathsToLink = [ "/bin" ]
      ; paths =
        [ stdenv git jdk config.programs.ssh.package nix ] ++ # default
        [ bash m4 stack texlive.combined.scheme-full wget ] ++
        (with haskellPackages; [ cpphs hscolour ] )
      ; };
    in [ env ];
  systemd.services."jenkins".serviceConfig.TimeoutSec = "5min";

  # 10% of the RAM is too little space
  services.logind.extraConfig = ''
    RuntimeDirectorySize=2G
  '';

  # Extra packages
  environment.systemPackages = with pkgs; [
    haskellPackages.hledger
    irssi
    perl
    texlive.combined.scheme-full
  ];
}
