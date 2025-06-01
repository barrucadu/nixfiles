{ lib, ... }:

with lib;

{
  options.nixfiles.finder = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Enable the finder service.
      '';
    };

    image = mkOption {
      type = types.str;
      description = ''
        Container image to run.
      '';
    };

    port = mkOption {
      type = types.int;
      default = 44986;
      description = ''
        Port (on 127.0.0.1) to expose finder on.
      '';
    };

    elasticsearchTag = mkOption {
      type = types.str;
      default = "9.0.1";
      description = ''
        Tag to use of the `elasticsearch` container image.
      '';
    };

    mangaDir = mkOption {
      type = types.path;
      example = "/mnt/nas/manga";
      description = ''
        Directory to serve manga files from.
      '';
    };
  };
}
