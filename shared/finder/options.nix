{ lib, ... }:

with lib;

{
  options.nixfiles.finder = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = mdDoc ''
        Enable the finder service.
      '';
    };

    image = mkOption {
      type = types.str;
      description = mdDoc ''
        Container image to use.
      '';
    };

    port = mkOption {
      type = types.int;
      default = 44986;
      description = mdDoc ''
        Port (on 127.0.0.1) to expose the finder service on.
      '';
    };

    esTag = mkOption {
      type = types.str;
      default = "8.0.0";
      description = mdDoc ''
        Tag to use of the `elasticsearch` container image.
      '';
    };

    mangaDir = mkOption {
      type = types.path;
      example = "/mnt/nas/manga";
      description = mdDoc ''
        Directory to serve manga files from.
      '';
    };
  };
}
