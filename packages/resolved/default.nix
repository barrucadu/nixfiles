{ rustPlatform, fetchFromGitHub, ... }:

rustPlatform.buildRustPackage rec {
  pname = "resolved";
  version = "5e056405a837c973cdff78fd79da1da05169f19f";

  src = fetchFromGitHub {
    owner = "barrucadu";
    repo = pname;
    rev = version;
    sha256 = "sha256-8VSzvnJfqzodsYUb4Q1jq4xeIthv3r8ewSxd9IF17Jw=";
  };

  cargoSha256 = "sha256-kWRRXB4Aip0kA3K9f5EnK+/dkljrHrC15hGidEBQeTo=";

  postInstall = ''
    cd config
    find . -type f -exec install -Dm 755 "{}" "$out/etc/resolved/{}" \;
  '';
}
