{ lib, ... }:

with lib;

{
  options.nixfiles.foundryvtt = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Enable the [FoundryVTT](https://foundryvtt.com/) service.
      '';
    };

    port = mkOption {
      type = types.int;
      default = 46885;
      description = ''
        Port (on 127.0.0.1) to expose FoundryVTT on.
      '';
    };

    dataDir = mkOption {
      type = types.str;
      default = "/var/lib/foundryvtt";
      description = ''
        Directory to store data files in.

        The downloaded FoundryVTT program files must be in `''${dataDir}/bin`.

        If the `erase-your-darlings` module is enabled, this is overridden to be
        on the persistent volume.
      '';
    };
  };
}
