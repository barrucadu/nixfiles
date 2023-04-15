{ poetry2nix, fetchFromGitHub, ... }:

let
  app = poetry2nix.mkPoetryApplication {
    projectDir = fetchFromGitHub {
      owner = "barrucadu";
      repo = "bookdb";
      rev = "3fbe6e5fe1bc96219c2f3c63d961c1ed71838a3e";
      sha256 = "sha256-kyN2tHWc0VP2qpbsL5ITa0zZKOgjHMX9sPNO+VbTzEk=";
    };

    overrides = poetry2nix.overrides.withDefaults (_: super: {
      elastic-transport = super.elastic-transport.overridePythonAttrs (old: { buildInputs = (old.buildInputs or [ ]) ++ [ super.setuptools ]; });
    });
  };
in
app.dependencyEnv
