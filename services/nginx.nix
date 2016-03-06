{config, lib, pkgs, ...}:

with lib;

let
  cfg = config.services.nginx;

  certdir = config.security.acme.directory;

  nginxdir = pkgs.nginx;

  makeHost = { hostname, certname ? null, config ? "" }: ''
    server {
      ${if cfg.enableSSL && certname != null then ''
        listen 443 ssl spdy;
        listen [::]:443 ssl spdy;

        ssl_certificate ${certdir}/${certname}/fullchain.pem;
        ssl_certificate_key ${certdir}/${certname}/key.pem;
      ''
      else ''
        listen 80;
        listen [::]:80;
      ''
      }

      add_header Strict-Transport-Security max-age=63072000;

      server_name ${hostname};

      ${config}
    }
  '';

  makeVirtualHost =
    {
      hostname ? "localhost",
      certname ? null,
      webdir   ? hostname,
      config   ? ""
    }:
    makeHost {
      hostname = hostname;
      certname = certname;
      config = ''
        access_log ${cfg.logdir}/${hostname}.access.log;
        error_log  ${cfg.logdir}/${hostname}.error.log;

        root  ${cfg.webroot}/${webdir};
        index index.html index.htm;

        ${config}
      '';
    };

  makeRedirect =
    {
      hostname ? "localhost",
      certname ? null,
      to       ? (if cfg.enableSSL && certname != null then "http://${hostname}" else "https://${hostname}"),
      config   ? "",
      httpAlso ? false
    }:
    makeHost {
      hostname = ".${hostname}";
      certname = certname;
      config = ''
	${if cfg.enableSSL && certname != null && httpAlso then "listen 80; listen [::]:80;" else ""}

        ${config}

        location / {
          return 301 ${to}$request_uri;
        }
      '';
    };

  gzipConfig = ''
    # Enable Gzip compressed.
    gzip on;

    # Compression level (1-9).
    # 5 is a perfect compromise between size and cpu usage, offering about
    # 75% reduction for most ascii files (almost identical to level 9).
    gzip_comp_level ${toString cfg.gzipCompLevel};

    # Don't compress anything that's already small and unlikely to shrink much
    # if at all (the default is 20 bytes, which is bad as that usually leads to
    # larger files after gzipping).
    gzip_min_length 256;

    # Compress data even for clients that are connecting to us via proxies,
    # identified by the "Via" header (required for CloudFront).
    gzip_proxied any;

    # Tell proxies to cache both the gzipped and regular version of a resource
    # whenever the client's Accept-Encoding capabilities header varies;
    # Avoids the issue where a non-gzip capable client (which is extremely rare
    # today) would display gibberish if their proxy gave them the gzipped version.
    gzip_vary on;

    # Compress all output labeled with one of the following MIME-types.
    gzip_types
      application/atom+xml
      application/javascript
      application/json
      application/ld+json
      application/manifest+json
      application/rss+xml
      application/vnd.geo+json
      application/vnd.ms-fontobject
      application/x-font-ttf
      application/x-web-app-manifest+json
      application/xhtml+xml
      application/xml
      font/opentype
      image/bmp
      image/svg+xml
      image/x-icon
      text/cache-manifest
      text/css
      text/plain
      text/vcard
      text/vnd.rim.location.xloc
      text/vtt
      text/x-component
      text/x-cross-domain-policy;
    # text/html is always compressed by HttpGzipModule

    # This should be turned on if you are going to have pre-compressed copies (.gz) of
    # static files available. If not it should be left off as it will cause extra I/O
    # for the check. It is best if you enable this in a location{} block for
    # a specific directory, or on an individual server{} level.
    gzip_static ${if cfg.gzipCheckStatic then "on" else "off"};
 '';

  sslConfig = ''
    # General SSL config. Use strong ciphers and protocols, preferring our
    # ciphers over the client's when handshaking. Keep a session cache with a
    # 10 minute timeout to avoid renegotiating on every page view. Use a
    # custom dhparam file rather than the openssl-provided parameters.
    ssl_prefer_server_ciphers on;
    ssl_ciphers AES256+EECDH:AES256+EDH:!aNULL;
    ssl_protocols TLSv1 TLSv1.1 TLSv1.2;

    ssl_session_cache builtin:1000 shared:SSL:10m;
    ssl_session_timeout 10m;
      
    ssl_stapling on;
    ssl_stapling_verify on;
    ${if cfg.dhparamFile == null then "" else "ssl_dhparam ${copyPathToStore cfg.dhparamFile};"}
 '';

  nginxConfig = ''
    # How many worker threads to run;
    # "auto" sets it to the number of CPU cores available in the system, and
    # offers the best performance. Don't set it higher than the number of CPU
    # cores if changing this parameter.

    # The maximum number of connections for Nginx is calculated by:
    # max_clients = worker_processes * worker_connections
    worker_processes auto;

    # Maximum open file descriptors per process;
    # should be > worker_connections.
    worker_rlimit_nofile 8192;

    events {
      # When you need > 8000 * cpu_cores connections, you start optimizing your OS,
      # and this is probably the point at which you hire people who are smarter than
      # you, as this is *a lot* of requests.
      worker_connections 8000;
    }

    # Default error log file
    # (this is only used when you don't override error_log on a server{} level)
    error_log  ${cfg.logdir}/error.log warn;

    http {
      # Hide nginx version information.
      server_tokens off;

      # Define the MIME types for files.
      include       ${nginxdir}/conf/mime.types;
      default_type  application/octet-stream;

      # Default log file
      # (this is only used when you don't override access_log on a server{} level)
      access_log ${cfg.logdir}/access.log;

      # How long to allow each connection to stay idle; longer values are better
      # for each individual client, particularly for SSL, but means that worker
      # connections are tied up longer. (Default: 75s)
      keepalive_timeout 20s;

      # Speed up file transfers by using sendfile() to copy directly
      # between descriptors rather than using read()/write().
      # For performance reasons, on FreeBSD systems w/ ZFS
      # this option should be disabled as ZFS's ARC caches
      # frequently used files in RAM by default.
      sendfile on;

      # Tell Nginx not to send out partial frames; this increases throughput
      # since TCP frames are filled up before being sent out. (adds TCP_CORK)
      tcp_nopush on;

      # Default character encoding
      charset utf-8;

      # Store temporary files in /var/spool
      client_body_temp_path /var/spool/nginx/client_body_temp 1 2;
      fastcgi_temp_path     /var/spool/nginx/fastcgi_temp     1 2;
      proxy_temp_path       /var/spool/nginx/proxy_temp       1 2;
      scgi_temp_path        /var/spool/nginx/scgi_temp        1 2;
      uwsgi_temp_path       /var/spool/nginx/uwsgi_temp       1 2;

      # Pull in gzip config if enabled
      ${if cfg.enableGzip then gzipConfig else ""}

      # Pull in SSL config if enabled
      ${if cfg.enableSSL then sslConfig else ""}

      # Drop requests for unknown hosts
      server {
        listen 80 default_server;
        listen [::]:80 default_server;

        return 444;
      }

      # Configure vhosts
      ${concatMapStringsSep "\n" makeVirtualHost cfg.hosts}

      # Configure redirects
      ${concatMapStringsSep "\n" makeRedirect cfg.redirects}
    }
  '';
in
{
  options = {
    services.nginx = {
      webroot = mkOption {
        default = "/srv/http";
        type = types.str;
        description = "Parent directory for all website files.";
      };

      logdir = mkOption {
        default = "/var/spool/nginx/logs";
        type = types.str;
        description = "Directory for all log files.";
      };

      enableGzip = mkOption {
        default = true;
        type = types.bool;
        description = "Enable gzip compression.";
      };

      gzipCompLevel = mkOption {
        default = 5;
        type = types.int;
        description = "The gzip compression level to use.";
      };

      gzipCheckStatic = mkOption {
        default = false;
        type = types.bool;
        description = "Check for .gz files.";
      };

      enableSSL = mkOption {
        default = true;
        type = types.bool;
        description = "Enable SSL encryption.";
      };

      dhparamFile = mkOption {
        default = null;
        type = types.nullOr types.path;
        description = "Custom ssl_dhparam file to override the openssl default.";
      };

      enablePHP = mkOption {
        default = false;
        type = types.bool;
        description = "Enable PHP scripts.";
      };

      hosts = mkOption {
        default = [];
        description = "List of hosts, in the format { hostname :: str, certname :: option str, webdir :: option str, config :: option str }";
      };

      redirects = mkOption {
        default = [];
        description = "List of redirects, in the format { hostname :: str, certname :: option str, to :: option str }";
      };
    };
  };

  config = {
    services.nginx =
      { enable = true
      ; config = nginxConfig
      ; } ;

    # Pull in simp_le for certificate renewal if SSL enabled.
    environment.systemPackages = with pkgs;
      if cfg.enableSSL then [ nginx simp_le ] else [ nginx ];

    # Configure PHP-FPM if PHP enabled.
    services.phpfpm.poolConfigs =
      let pool = ''
        user = nginx
        group = nginx
        listen = /run/php-fpm/php-fpm.sock
        listen.owner = nginx
        listen.group = nginx
        pm = dynamic
        pm.max_children = 5
        pm.start_servers = 2
        pm.min_spare_servers = 1
        pm.max_spare_servers = 3
      '';
      in if cfg.enablePHP then { nginx = pool; } else { };
  };
}
