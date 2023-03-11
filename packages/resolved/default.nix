{ rustPlatform, fetchFromGitHub, ... }:

rustPlatform.buildRustPackage rec {
  pname = "resolved";
  version = "3b9e0efe3c60526d25f19753895aae60b07743d7";

  src = fetchFromGitHub {
    owner = "barrucadu";
    repo = pname;
    rev = version;
    sha256 = "sha256-004dT+5P0wTi6t/8C8yxYoDIgOXmgUgIXitgmttfWQ4=";
  };

  cargoSha256 = "sha256-ioP22XITAIxM+2L1+uraCwId52oAQ0tdYPZdBPXi3rM=";

  postInstall = ''
    cd config
    find . -type f -exec install -Dm 755 "{}" "$out/etc/resolved/{}" \;
  '';
}
