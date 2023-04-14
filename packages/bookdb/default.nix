{ poetry2nix, fetchFromGitHub, ... }:

let
  app = poetry2nix.mkPoetryApplication {
    projectDir = fetchFromGitHub {
      owner = "barrucadu";
      repo = "bookdb";
      rev = "2a5e5456b9d944f26ece8157092564d066346de4";
      sha256 = "sha256-5xXcf9CV3yUs5J4QS/S+jOazdq8nHmFtvJbdiRmyzGI=";
    };

    overrides = poetry2nix.overrides.withDefaults (_: super: {
      elastic-transport = super.elastic-transport.overridePythonAttrs (old: { buildInputs = (old.buildInputs or [ ]) ++ [ super.setuptools ]; });
    });
  };
in
app.dependencyEnv
