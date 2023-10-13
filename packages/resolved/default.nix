{ rustPlatform, fetchFromGitHub, ... }:

rustPlatform.buildRustPackage rec {
  pname = "resolved";
  version = "cc43b526dea18825288fa03a0c4a3ce98f053856";

  src = fetchFromGitHub {
    owner = "barrucadu";
    repo = pname;
    rev = version;
    sha256 = "sha256-gox2b9bqerH0rgC3CvJedvW1vP1vMpDZwKpHBWHQK7E=";
  };

  cargoSha256 = "sha256-YP2xPccVj7NDqDxSlqgVrmTsG1x9NWHSUxp0OOsf+ZE=";

  postInstall = ''
    cd config
    find . -type f -exec install -Dm 755 "{}" "$out/etc/resolved/{}" \;
  '';
}
