# A database and web app to keep track of all my books.
{ rustPlatform, fetchFromGitHub, openssl, pkg-config, ... }:

let
  githubOwner = "barrucadu";
  githubRepo = "bookdb";
  githubRev = "a8ae9b427d08ef7e30eee57ce43a367e85f63e70";
in
rustPlatform.buildRustPackage {
  pname = githubRepo;
  version = githubRev;

  src = fetchFromGitHub {
    owner = githubOwner;
    repo = githubRepo;
    rev = githubRev;
    sha256 = "sha256-7hD2BPEIl2j9dS86Bvx6ERTKzV84zzAp7b/jH48cUoY=";
  };

  cargoSha256 = "sha256-3/T6DKWkKjrxu3b25nDunmd3zGThL7uDre1pJ+HXkMc=";

  nativeBuildInputs = [ pkg-config ];
  buildInputs = [ openssl ];
}
