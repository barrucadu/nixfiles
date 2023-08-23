{ buildGoModule, fetchFromGitHub, ... }:

buildGoModule rec {
  pname = "prometheus-awair-exporter";
  version = "2d598d18a80277e022ff1e2ebbb84ec19f7e79a0";

  src = fetchFromGitHub {
    owner = "barrucadu";
    repo = pname;
    rev = version;
    sha256 = "sha256-pgf5qCaENi0OHazBqdpgcnPXi7ZPqFaA7olNBwANaP0=";
  };

  vendorSha256 = "sha256-c2T6T+viz6+VpfQMHDED8JdvwC1H3qrAs7SzCvPektk=";
}
