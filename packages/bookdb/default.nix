{ poetry2nix, fetchFromGitHub, ... }:

let
  app = poetry2nix.mkPoetryApplication {
    projectDir = fetchFromGitHub {
      owner = "barrucadu";
      repo = "bookdb";
      rev = "cb17cdc6ce63a38d8ebfec8e82c57e51a86a63a0";
      sha256 = "sha256-W5bHAgzC+6u5sdVgta/NhCLz7NSHHOnKcQXPxsU3dB8=";
    };

    overrides = poetry2nix.overrides.withDefaults (_: super: {
      elastic-transport = super.elastic-transport.overridePythonAttrs (old: { buildInputs = (old.buildInputs or [ ]) ++ [ super.setuptools ]; });
    });

    postFixup = ''
      cd config
      find . -type f -exec install -Dm 755 "{}" "$out/etc/bookdb/config/{}" \;
    '';
  };
in
app.dependencyEnv
