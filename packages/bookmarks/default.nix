# A database and web app to keep track of my bookmarks.
{ rustPlatform, fetchFromGitHub, openssl, pkg-config, ... }:

let
  githubOwner = "barrucadu";
  githubRepo = "bookmarks";
  githubRev = "ba0355602445d02a818a03d7343eecf19eadde7f";
in
rustPlatform.buildRustPackage {
  pname = githubRepo;
  version = githubRev;

  src = fetchFromGitHub {
    owner = githubOwner;
    repo = githubRepo;
    rev = githubRev;
    sha256 = "sha256-XSpE7XnieEIjwXewGKij6AXOaonCsKZC6zwx60Z3foI=";
  };

  cargoSha256 = "sha256-b2nFcK3UnYYSAfKdbQdhEyWDhp/FUBZXvN1/TfgKkHs=";

  nativeBuildInputs = [ pkg-config ];
  buildInputs = [ openssl ];
}
