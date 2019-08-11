{ config, pkgs, ... }:

let
  nginx = pkgs.nginx.override { modules = [
    pkgs.nginxModules.brotli
    pkgs.nginxModules.lua
  ]; };

  security_header_settings = ''
    header_filter_by_lua_block {
      if not ngx.header["Access-Control-Allow-Origin"] then
        ngx.header["Access-Control-Allow-Origin"] = "*"
      end

      if not ngx.header["Content-Security-Policy"] then
        ngx.header["Content-Security-Policy"] = "default-src 'self'; script-src 'self' 'unsafe-inline' 'unsafe-eval'; style-src 'self' 'unsafe-inline'"
      end

      if not ngx.header["Referrer-Policy"] then
        ngx.header["Referrer-Policy"] = "strict-origin-when-cross-origin"
      end

      if not ngx.header["Strict-Transport-Security"] then
        ngx.header["Strict-Transport-Security"] = "max-age=31536000; includeSubDomains"
      end

      if not ngx.header["X-Content-Type-Options"] then
        ngx.header["X-Content-Type-Options"] = "nosniff"
      end

      if not ngx.header["X-Frame-Options"] then
        ngx.header["X-Frame-Options"] = "SAMEORIGIN"
      end

      if not ngx.header["X-XSS-Protection"] then
        ngx.header["X-XSS-Protection"] = "1; mode=block"
      end
    }
  '';

  brotli_settings = ''
    brotli on;
    brotli_comp_level 11;
    brotli_types text/plain text/css application/json application/javascript text/xml application/xml application/xml+rss text/javascript;
  '';

  proxy_settings = ''
    proxy_max_temp_file_size 0;
  '';

  extra_mime_types = ''
    types {
      application/octet-stream mkv;
      application/octet-stream tar;
    }
  '';
in

{
  services.nginx.enable = true;
  services.nginx.package = nginx;

  services.nginx.recommendedGzipSettings  = true;
  services.nginx.recommendedOptimisation  = true;
  services.nginx.recommendedProxySettings = true;
  services.nginx.recommendedTlsSettings   = true;

  services.nginx.appendHttpConfig = ''
    ${security_header_settings}
    ${brotli_settings}
    ${proxy_settings}
    ${extra_mime_types}
  '';
}
