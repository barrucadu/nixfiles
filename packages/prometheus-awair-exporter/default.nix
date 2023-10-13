{ buildGoModule, fetchFromGitHub, ... }:

buildGoModule rec {
  pname = "prometheus-awair-exporter";
  version = "87c534bc15a10d1a1158aa543e467a2e0e175bd1";

  src = fetchFromGitHub {
    owner = "barrucadu";
    repo = pname;
    rev = version;
    sha256 = "sha256-v3VRECer+zTcLiS8sRXgWZMwQMNv8vyZeryJ4/XOKhQ=";
  };

  vendorSha256 = "sha256-i9Es8OS7T/g35lNkxj/XRqbFBTl426U1xKZ9Ecz8sGM=";
}
