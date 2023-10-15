#  A simple DNS server for home networks.
{ rustPlatform, fetchFromGitHub, ... }:

let
  githubOwner = "barrucadu";
  githubRepo = "resolved";
  githubRev = "cc43b526dea18825288fa03a0c4a3ce98f053856";
in
rustPlatform.buildRustPackage {
  pname = githubRepo;
  version = githubRev;

  src = fetchFromGitHub {
    owner = githubOwner;
    repo = githubRepo;
    rev = githubRev;
    sha256 = "sha256-gox2b9bqerH0rgC3CvJedvW1vP1vMpDZwKpHBWHQK7E=";
  };

  cargoSha256 = "sha256-YP2xPccVj7NDqDxSlqgVrmTsG1x9NWHSUxp0OOsf+ZE=";

  postInstall = ''
    cd config
    find . -type f -exec install -Dm 755 "{}" "$out/etc/resolved/{}" \;
  '';
}
