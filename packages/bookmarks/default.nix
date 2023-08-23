{ poetry2nix, fetchFromGitHub, ... }:

let
  app = poetry2nix.mkPoetryApplication {
    projectDir = fetchFromGitHub {
      owner = "barrucadu";
      repo = "bookmarks";
      rev = "555dddba3d8e05ac29b3cb282ed76c997ff752c6";
      sha256 = "sha256-VNEhhPLxEsDSmZzO3QMPK3TVSfOpiPntLTVcWNVmUHY=";
    };

    overrides = poetry2nix.overrides.withDefaults (self: super: {
      beautifulsoup4 = super.beautifulsoup4.overridePythonAttrs (old: {
        buildInputs = (old.buildInputs or [ ]) ++ [ self.hatchling ];
      });
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
