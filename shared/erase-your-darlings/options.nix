{ lib, ... }:

with lib;

{
  options.nixfiles.eraseYourDarlings = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = mdDoc ''
        Enable wiping `/` on boot and storing persistent data in
        `''${persistDir}`.
      '';
    };

    barrucaduPasswordFile = mkOption {
      type = types.str;
      description = mdDoc ''
        File containing the hashed password for `barrucadu`.

        If using [sops-nix](https://github.com/Mic92/sops-nix) set the
        `neededForUsers` option on the secret.
      '';
    };

    rootSnapshot = mkOption {
      type = types.str;
      default = "local/volatile/root@blank";
      description = mdDoc ''
        ZFS snapshot to roll back to on boot.
      '';
    };

    persistDir = mkOption {
      type = types.path;
      default = "/persist";
      description = mdDoc ''
        Persistent directory which will not be erased.  This must be on a
        different ZFS dataset that will not be wiped when rolling back to the
        `rootSnapshot`.

        This module moves various files from `/` to here.
      '';
    };

    machineId = mkOption {
      type = types.str;
      example = "64b1b10f3bef4616a7faf5edf1ef3ca5";
      description = mdDoc ''
        An arbitrary 32-character hexadecimal string, used to identify the host.
        This is needed for journalctl logs from previous boots to be accessible.

        See [the systemd documentation](https://www.freedesktop.org/software/systemd/man/machine-id.html).
      '';
    };
  };
}
