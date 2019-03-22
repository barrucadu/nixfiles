{ config, pkgs, lib, ... }:

with lib;

{
  networking.hostName = "dunwich";

  imports = [
    ../services/bookdb.nix
    ../services/nginx.nix
    ../services/nginx-phpfpm.nix
  ];

  # Bootloader
  boot.loader.grub.enable  = true;
  boot.loader.grub.version = 2;
  boot.loader.grub.device  = "/dev/sda";

  # Firewall and container NAT
  networking.firewall.allowedTCPPorts = [ 80 443 ];
  networking.firewall.allowedUDPPortRanges = [ { from = 60000; to = 61000; } ];

  networking.nat.enable = true;
  networking.nat.internalInterfaces = ["ve-+"];
  networking.nat.externalInterface = "ens4";

  # Web server
  services.nginx.commonHttpConfig = ''
    log_format combined_vhost '$host '
                              '$remote_addr - $remote_user [$time_local] '
                              '"$request" $status $body_bytes_sent '
                              '"$http_referer" "$http_user_agent"';
    access_log logs/access.log combined_vhost;
  '';

  services.nginx.virtualHosts = {
    default = { default = true; locations."/".root = "/srv/http/default"; };

    "dunwich.barrucadu.co.uk" = { enableACME = true; globalRedirect = "www.dunwich.barrucadu.co.uk"; };
    "dunwich.barrucadu.com"   = { enableACME = true; globalRedirect = "www.dunwich.barrucadu.co.uk"; };
    "dunwich.barrucadu.uk"    = { enableACME = true; globalRedirect = "www.dunwich.barrucadu.co.uk"; };
    "dunwich.uzbl.org"        = { enableACME = true; globalRedirect = "www.dunwich.uzbl.org"; };

    "www.dunwich.barrucadu.co.uk" = {
      enableACME = true;
      forceSSL = true;
      root = "/srv/http/barrucadu.co.uk/www";
      locations."/bookdb/".proxyPass = "http://127.0.0.1:3000";
      locations."/bookdb/covers/".extraConfig = "alias /srv/bookdb/covers/;";
      locations."/bookdb/static/".extraConfig = "alias /srv/bookdb/static/;";
      extraConfig = "include /srv/http/barrucadu.co.uk/www.conf;";
    };

    "ci.dunwich.barrucadu.co.uk" = {
      enableACME = true;
      forceSSL = true;
      locations."/".proxyPass = "http://127.0.0.1:${toString config.services.jenkins.port}";
    };

    "memo.barrucadu.co.uk" = {
      enableACME = true;
      forceSSL = true;
      root = "/srv/http/barrucadu.co.uk/memo";
    };

    "misc.barrucadu.co.uk" = {
      enableACME = true;
      forceSSL = true;
      root = "/srv/http/barrucadu.co.uk/misc";
      locations."~ /7day/.*/".extraConfig    = "autoindex on;";
      locations."~ /14day/.*/".extraConfig   = "autoindex on;";
      locations."~ /28day/.*/".extraConfig   = "autoindex on;";
      locations."~ /forever/.*/".extraConfig = "autoindex on;";
    };

    "www.dunwich.uzbl.org" = {
      enableACME = true;
      forceSSL = true;
      root = "/srv/http/uzbl.org/www";
      locations."= /archives.php".extraConfig    = "rewrite ^(.*) /index.php;";
      locations."= /faq.php".extraConfig         = "rewrite ^(.*) /index.php;";
      locations."= /readme.php".extraConfig      = "rewrite ^(.*) /index.php;";
      locations."= /keybindings.php".extraConfig = "rewrite ^(.*) /index.php;";
      locations."= /get.php".extraConfig         = "rewrite ^(.*) /index.php;";
      locations."= /community.php".extraConfig   = "rewrite ^(.*) /index.php;";
      locations."= /contribute.php".extraConfig  = "rewrite ^(.*) /index.php;";
      locations."= /commits.php".extraConfig     = "rewrite ^(.*) /index.php;";
      locations."= /news.php".extraConfig        = "rewrite ^(.*) /index.php;";
      locations."/doesitwork/".extraConfig       = "rewrite ^(.*) /index.php;";
      locations."/fosdem2010/".extraConfig       = "rewrite ^(.*) /index.php;";
      locations."/wiki/".tryFiles = "$uri $uri/ @dokuwiki";
      locations."~ /wiki/(data/|conf/|bin/|inc/|install.php)".extraConfig = "deny all;";
      locations."@dokuwiki".extraConfig = ''
        rewrite ^/wiki/_media/(.*) /wiki/lib/exe/fetch.php?media=$1 last;
        rewrite ^/wiki/_detail/(.*) /wiki/lib/exe/detail.php?media=$1 last;
        rewrite ^/wiki/_export/([^/]+)/(.*) /wiki/doku.php?do=export_$1&id=$2 last;
        rewrite ^/wiki/(.*) /wiki/doku.php?id=$1&$args last;
      '';
      locations."~ \.php$".extraConfig = ''
        include ${pkgs.nginx}/conf/fastcgi_params;
        fastcgi_pass  unix:/run/phpfpm/phpfpm.sock;
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME $document_root/$fastcgi_script_name;
      '';
      extraConfig = "index index.php;";
    };
  };

  # Clear the misc files every so often
  systemd.tmpfiles.rules =
    [ "d /srv/http/barrucadu.co.uk/misc/7day  0755 barrucadu users  7d"
      "d /srv/http/barrucadu.co.uk/misc/14day 0755 barrucadu users 14d"
      "d /srv/http/barrucadu.co.uk/misc/28day 0755 barrucadu users 28d"
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

  # Uzbl cronjobs (todo: jenkins jobs, scheduled or webhooks)
  systemd.services.git-pull-uzbl-website =
    { enable   = true
    ; script = "exec ${pkgs.git}/bin/git pull"
    ; startAt = "hourly"
    ; serviceConfig.WorkingDirectory = "/srv/http/uzbl.org/www"
    ; };
  systemd.services.git-pull-uzbl =
    { enable   = true
    ; script = "exec ${pkgs.git}/bin/git pull"
    ; startAt = "hourly"
    ; serviceConfig.WorkingDirectory = "/srv/http/uzbl.org/uzbl"
    ; };

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
