{ config, pkgs, ... }:

let
  nginxWithLua = pkgs.nginx.override { modules = [ pkgs.nginxModules.lua ]; };
in

{
  services.nginx.enable = true;
  services.nginx.package = nginxWithLua;

  services.nginx.recommendedGzipSettings  = true;
  services.nginx.recommendedOptimisation  = true;
  services.nginx.recommendedProxySettings = true;
  services.nginx.recommendedTlsSettings   = true;

  services.nginx.appendHttpConfig = ''
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

    proxy_max_temp_file_size 0;
  '';
}
