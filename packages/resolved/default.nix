{ rustPlatform, fetchFromGitHub, ... }:

rustPlatform.buildRustPackage rec {
  pname = "resolved";
  version = "fac82efaaf73166a70d43b06e7c7ca82ddd9485e";

  src = fetchFromGitHub {
    owner = "barrucadu";
    repo = pname;
    rev = version;
    sha256 = "sha256-MkyMbSBex66T+HUSchy70SYtgUP0peoxGBk9A9IAFZk=";
  };

  cargoSha256 = "sha256-tJn9toqNr7DxfD43KBYQnY2kzjFSTPvCtd7jenA7YbY=";

  postInstall = ''
    cd config
    find . -type f -exec install -Dm 755 "{}" "$out/etc/resolved/{}" \;
  '';
}
