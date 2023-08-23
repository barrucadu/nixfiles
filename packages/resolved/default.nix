{ rustPlatform, fetchFromGitHub, ... }:

rustPlatform.buildRustPackage rec {
  pname = "resolved";
  version = "47da2a112e07bee239c7d2d54a7184946980d3bd";

  src = fetchFromGitHub {
    owner = "barrucadu";
    repo = pname;
    rev = version;
    sha256 = "sha256-aCkhSUHS268cXFdw/YMjZkV0LbPrAq0MpQ+P25M6z6I=";
  };

  cargoSha256 = "sha256-Y+XKddzHY2Uk68Oeb4vSPULAnbiVV7ed/Obm8ki3dxQ=";

  postInstall = ''
    cd config
    find . -type f -exec install -Dm 755 "{}" "$out/etc/resolved/{}" \;
  '';
}
