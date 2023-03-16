{ poetry2nix, fetchFromGitHub, ... }:

let
  app = poetry2nix.mkPoetryApplication {
    projectDir = fetchFromGitHub {
      owner = "barrucadu";
      repo = "bookmarks";
      rev = "c631c387c10cb8ff090ea90515734c3954a10079";
      sha256 = "sha256-5QxYJ5Tofhfxu9ixZNEOR4BT+Wwx/HdBKvpSZv6WB0c=";
    };

    overrides = poetry2nix.overrides.withDefaults (_: super: {
      elastic-transport = super.elastic-transport.overridePythonAttrs (old: { buildInputs = (old.buildInputs or [ ]) ++ [ super.setuptools ]; });
    });
  };
in
app.dependencyEnv
