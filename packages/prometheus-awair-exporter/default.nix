# A simple Awair exporter for Prometheus.
{ buildGoModule, fetchFromGitHub, ... }:

let
  githubOwner = "barrucadu";
  githubRepo = "prometheus-awair-exporter";
  githubRev = "87c534bc15a10d1a1158aa543e467a2e0e175bd1";
in
buildGoModule {
  pname = githubRepo;
  version = githubRev;

  src = fetchFromGitHub {
    owner = githubOwner;
    repo = githubRepo;
    rev = githubRev;
    sha256 = "sha256-v3VRECer+zTcLiS8sRXgWZMwQMNv8vyZeryJ4/XOKhQ=";
  };

  vendorHash = "sha256-i9Es8OS7T/g35lNkxj/XRqbFBTl426U1xKZ9Ecz8sGM=";
}
