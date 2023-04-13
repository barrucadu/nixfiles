{ poetry2nix, fetchFromGitHub, ... }:

let
  app = poetry2nix.mkPoetryApplication {
    projectDir = fetchFromGitHub {
      owner = "barrucadu";
      repo = "bookdb";
      rev = "9a33a65b6d759ce072f683681c48dc4a9877a9bc";
      sha256 = "sha256-gXcr3xelTDYZ0/hnsnDwoOPEXmDMQj/AAgaOOB/KVCo=";
    };

    overrides = poetry2nix.overrides.withDefaults (_: super: {
      elastic-transport = super.elastic-transport.overridePythonAttrs (old: { buildInputs = (old.buildInputs or [ ]) ++ [ super.setuptools ]; });
    });
  };
in
app.dependencyEnv
