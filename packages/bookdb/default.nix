{ poetry2nix, fetchFromGitHub, ... }:

let
  app = poetry2nix.mkPoetryApplication {
    projectDir = fetchFromGitHub {
      owner = "barrucadu";
      repo = "bookdb";
      rev = "6040d270ae7ac7ecec09849885b6405d0650dff2";
      sha256 = "sha256-U93t2dbGjBej6+IsI2mUVqm0Sirw/DIJqYH0USUF7to=";
    };

    overrides = poetry2nix.overrides.withDefaults (self: super: {
      elastic-transport = super.elastic-transport.overridePythonAttrs (old: {
        buildInputs = (old.buildInputs or [ ]) ++ [ self.setuptools ];
      });
    });
  };
in
app.dependencyEnv
