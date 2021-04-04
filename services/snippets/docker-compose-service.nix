{ lib
, pkgs
, composeProjectName
, yaml
, execStartPre ? null
, ...
}:

let
  dockerComposeFile = pkgs.writeText "docker-compose.yml" yaml;
in

{
  enable = true;
  wantedBy = [ "multi-user.target" ];
  requires = [ "docker.service" ];
  environment = { COMPOSE_PROJECT_NAME = composeProjectName; };
  serviceConfig = lib.mkMerge [
    (lib.mkIf (execStartPre != null) { ExecStartPre = "${execStartPre}"; })
    {
      ExecStart = "${pkgs.docker_compose}/bin/docker-compose -f '${dockerComposeFile}' up";
      ExecStop = "${pkgs.docker_compose}/bin/docker-compose -f '${dockerComposeFile}' stop";
      Restart = "always";
    }
  ];
}
