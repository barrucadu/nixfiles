{ rustPlatform, fetchFromGitHub, ... }:

rustPlatform.buildRustPackage rec {
  pname = "resolved";
  version = "c065a4afaffcb2599708d3837b0ce4986b2465c7";

  src = fetchFromGitHub {
    owner = "barrucadu";
    repo = pname;
    rev = version;
    sha256 = "sha256-6KCL/FyETdHpncx2HorpIw20pw9sI2aJSd7hJREWmIM=";
  };

  cargoSha256 = "sha256-69Q31l28yV+FbSrI/EaPmgLgDNJcAOQ0zmZQi43ZqOQ=";

  postInstall = ''
    cd config
    find . -type f -exec install -Dm 755 "{}" "$out/etc/resolved/{}" \;
  '';
}
