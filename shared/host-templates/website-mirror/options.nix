{ lib, ... }:

with lib;

{
  options.nixfiles.hostTemplates.websiteMirror = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Enable the website-mirror template.
      '';
    };

    acmeEnvironmentFile = mkOption {
      type = types.path;
      description = ''
        Environment file with AWS Route53 credentials for the ACME DNS-01 challenge.
      '';
    };

    concourseDeployRobotAuthorizedKeys = mkOption {
      type = types.listOf types.str;
      default =
        [ "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFilTWek5xNpl82V48oQ99briJhn9BqwCACeRq1dQnZn concourse-worker@cd.barrucadu.dev" ];
      description = ''
        SSH public keys to allow Concourse deployments from.
      '';
    };

    bookdbRemoteSyncAuthorizedKeys = mkOption {
      type = types.listOf types.str;
      default =
        [ "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIChVw9DPLafA3lCLCI4Df9rYuxedFQTXAwDOOHUfZ0Ac remote-sync@nyarlathotep" ];
      description = ''
        SSH public keys to allow bookdb remots sync from.
      '';
    };

    bookmarksRemoteSyncAuthorizedKeys = mkOption {
      type = types.listOf types.str;
      default =
        [ "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIChVw9DPLafA3lCLCI4Df9rYuxedFQTXAwDOOHUfZ0Ac remote-sync@nyarlathotep" ];
      description = ''
        SSH public keys to allow bookdb remots sync from.
      '';
    };
  };
}
