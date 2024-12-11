{ lib, ... }:

with lib;

{
  options.nixfiles.concourse = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Enable the [Concourse CI](https://concourse-ci.org/) service.
      '';
    };

    concourseTag = mkOption {
      type = types.str;
      default = "7.11.2";
      description = ''
        Tag to use of the `concourse/concourse` container image.
      '';
    };

    githubUser = mkOption {
      type = types.str;
      default = "barrucadu";
      description = ''
        The GitHub user to authenticate with.
      '';
    };

    port = mkOption {
      type = types.int;
      default = 46498;
      description = ''
        Port (on 127.0.0.1) to expose Concourse CI on.
      '';
    };

    metricsPort = mkOption {
      type = types.int;
      default = 45811;
      description = ''
        Port (on 127.0.0.1) to expose the Prometheus metrics on.
      '';
    };

    postgresTag = mkOption {
      type = types.str;
      default = "16";
      description = ''
        Tag to use of the `postgres` container image.
      '';
    };

    workerScratchDir = mkOption {
      type = types.nullOr types.path;
      default = null;
      description = ''
        Mount a directory from the host into the worker container to use as
        temporary storage.  This is useful if the filesystem used for container
        volumes isn't very big.
      '';
    };

    environmentFile = mkOption {
      type = types.str;
      description = ''
        Environment file to pass secrets into the service.  This is of the form:

        ```text
        # GitHub OAuth credentials
        CONCOURSE_GITHUB_CLIENT_ID="..."
        CONCOURSE_GITHUB_CLIENT_SECRET="..."

        # AWS SSM credentials
        CONCOURSE_AWS_SSM_REGION="..."
        CONCOURSE_AWS_SSM_ACCESS_KEY="..."
        CONCOURSE_AWS_SSM_SECRET_KEY="..."
        ```
      '';
    };
  };
}
