{ rustPlatform, fetchFromGitHub, ... }:

rustPlatform.buildRustPackage rec {
  pname = "resolved";
  version = "7900906b2c6f67ab28265dd2df520ab5fb973f0e";

  src = fetchFromGitHub {
    owner = "barrucadu";
    repo = pname;
    rev = version;
    sha256 = "sha256-ZbabeNdd5Yfem4bYCGG0BBmkOGsS5LDoZoRVs3ulA7E=";
  };

  cargoSha256 = "sha256-tsLh+6yctoBqgLYndRpbGQmy7FHrXkQiQClpexfnjFY=";

  postInstall = ''
    cd config
    find . -type f -exec install -Dm 755 "{}" "$out/etc/resolved/{}" \;
  '';
}
