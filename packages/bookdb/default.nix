{ poetry2nix, fetchFromGitHub, ... }:

let
  app = poetry2nix.mkPoetryApplication {
    projectDir = fetchFromGitHub {
      owner = "barrucadu";
      repo = "bookdb";
      rev = "0d202dcfa12e05212ef28e4e04ff7446707558a2";
      sha256 = "sha256-HgLmBxmtTJFcFHbzi1MtvhndaETokJtXcTjRrqJjsFQ=";
    };

    overrides = poetry2nix.overrides.withDefaults (_: super: {
      elastic-transport = super.elastic-transport.overridePythonAttrs (old: { buildInputs = (old.buildInputs or [ ]) ++ [ super.setuptools ]; });
    });
  };
in
app.dependencyEnv
