# A database and web app to keep track of all my books.
{ rustPlatform, fetchFromGitHub, openssl, pkg-config, ... }:

let
  githubOwner = "barrucadu";
  githubRepo = "bookdb";
  githubRev = "47ef43ed5815eb3e9ad545966ab96328adf3339d";
in
rustPlatform.buildRustPackage {
  pname = githubRepo;
  version = githubRev;

  src = fetchFromGitHub {
    owner = githubOwner;
    repo = githubRepo;
    rev = githubRev;
    sha256 = "sha256-SexmGBZiv5Lb0clrYHb5WRgt3IAzwgqC+sgM7PWFCIQ=";
  };

  cargoSha256 = "sha256-JtVH04p2MqyGdWDLopIN4aZEIvKnDpYoonBqm6Sdz9s=";

  nativeBuildInputs = [ pkg-config ];
  buildInputs = [ openssl ];
}
