{ poetry2nix, fetchFromGitHub, ... }:

let
  app = poetry2nix.mkPoetryApplication {
    projectDir = fetchFromGitHub {
      owner = "barrucadu";
      repo = "bookdb";
      rev = "4302546248c9006da32423f08d6b368d5e659fb4";
      sha256 = "sha256-i+0HoZErkAkKYvr5nZhCXTMwsXDhqv+2qn4rB7xIsGs=";
    };

    overrides = poetry2nix.overrides.withDefaults (self: super: {
      elastic-transport = super.elastic-transport.overridePythonAttrs (old: {
        buildInputs = (old.buildInputs or [ ]) ++ [ self.setuptools ];
      });
      flask = super.flask.overridePythonAttrs (old: {
        buildInputs = (old.buildInputs or [ ]) ++ [ self.setuptools self.flit-core ];
      });
      gunicorn = super.gunicorn.overridePythonAttrs (old: {
        buildInputs = (old.buildInputs or [ ]) ++ [ self.setuptools self.packaging ];
      });
      werkzeug = super.werkzeug.overridePythonAttrs (old: {
        buildInputs = (old.buildInputs or [ ]) ++ [ self.setuptools self.flit-core ];
      });
    });
  };
in
app.dependencyEnv
