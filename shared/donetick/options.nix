{ lib, ... }:

with lib;

{
  options.nixfiles.donetick = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Enable the [donetick](https://donetick.com/) service.
      '';
    };

    port = mkOption {
      type = types.int;
      default = 46399;
      description = ''
        Port (on 127.0.0.1) to expose Pleroma on.
      '';
    };

    tag = mkOption {
      type = types.str;
      default = "v0.1.76";
      description = ''
        Tag to use of the `donetick/donetick` container image.
      '';
    };

    domain = mkOption {
      type = types.str;
      example = "todo.nyarlathotep.lan";
      description = ''
        Domain which donetick will be exposed on.
      '';
    };

    environmentFile = mkOption {
      type = types.str;
      description = ''
        File containing secret configuration.
      '';
    };
  };
}
