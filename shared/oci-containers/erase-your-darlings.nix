{ config, lib, ... }:

with lib;
let
  eyd = config.nixfiles.eraseYourDarlings;
in
{
  config = mkIf eyd.enable {
    nixfiles.oci-containers.volumeBaseDir = "${toString eyd.persistDir}/docker-volumes";
  };
}
