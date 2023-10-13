{ poetry2nix, fetchFromGitHub, ... }:

let
  app = poetry2nix.mkPoetryApplication {
    projectDir = fetchFromGitHub {
      owner = "barrucadu";
      repo = "bookmarks";
      rev = "afe9c2a59c1e9d385074e17d684ac0ae7556fced";
      sha256 = "sha256-uSsycnSWpIBc7SojptIgvjLkoZ0gTScelfygLJ9zvxI=";
    };

    overrides = poetry2nix.overrides.withDefaults (self: super: {
      elastic-transport = super.elastic-transport.overridePythonAttrs (old: {
        buildInputs = (old.buildInputs or [ ]) ++ [ self.setuptools ];
      });
    });
  };
in
app.dependencyEnv
