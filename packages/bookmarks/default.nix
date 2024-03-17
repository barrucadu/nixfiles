# A database and web app to keep track of my bookmarks.
{ rustPlatform, fetchFromGitHub, openssl, pkg-config, ... }:

let
  githubOwner = "barrucadu";
  githubRepo = "bookmarks";
  githubRev = "236385a0b22396fd3136b2214edfbeb4a0aa26de";
in
rustPlatform.buildRustPackage {
  pname = githubRepo;
  version = githubRev;

  src = fetchFromGitHub {
    owner = githubOwner;
    repo = githubRepo;
    rev = githubRev;
    sha256 = "sha256-PLrDwGfePmgeLTOcCFP9OLRjQaSosUHxfIH397PlSdE=";
  };

  cargoSha256 = "sha256-sN3Gj/kOQS8MQklBa5vCk5+o/kQihpZh+7I+JUohBzg=";

  nativeBuildInputs = [ pkg-config ];
  buildInputs = [ openssl ];
}
