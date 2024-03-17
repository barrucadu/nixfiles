#  A simple DNS server for home networks.
{ rustPlatform, fetchFromGitHub, ... }:

let
  githubOwner = "barrucadu";
  githubRepo = "resolved";
  githubRev = "d99013dd1de52f74e5dc3dcdbff628e5f33e624b";
in
rustPlatform.buildRustPackage {
  pname = githubRepo;
  version = githubRev;

  src = fetchFromGitHub {
    owner = githubOwner;
    repo = githubRepo;
    rev = githubRev;
    sha256 = "sha256-kH2frFYuoMVX9b3uFl325zHuWG2Y0XhNE6lSYk8AD0g=";
  };

  cargoSha256 = "sha256-vGgvECImU7QSxBdrS4cCAkAzYWEhx/vRp5nSJkWCpck=";

  postInstall = ''
    cd config
    find . -type f -exec install -Dm 755 "{}" "$out/etc/resolved/{}" \;
  '';
}
