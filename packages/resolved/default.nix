{ rustPlatform, fetchFromGitHub, ... }:

rustPlatform.buildRustPackage rec {
  pname = "resolved";
  version = "32c92d919a440c53f8a127d4e04ce848284260e5";

  src = fetchFromGitHub {
    owner = "barrucadu";
    repo = pname;
    rev = version;
    sha256 = "sha256-L1ix6/w7G9McBBio2Q9AG9KB/C0Sfc4goZFmYvPDVT0=";
  };

  cargoSha256 = "sha256-D/sqG3PnCS0ormV+PgZLk/p6fSOyhcCNaHV3qRXDh5Q=";

  postInstall = ''
    cd config
    find . -type f -exec install -Dm 755 "{}" "$out/etc/resolved/{}" \;
  '';
}
