{ buildGoModule, fetchFromGitHub, ... }:

buildGoModule rec {
  pname = "prometheus-awair-exporter";
  version = "f154bbdc401886a1311d80d19d4461a0915ed310";

  src = fetchFromGitHub {
    owner = "barrucadu";
    repo = pname;
    rev = version;
    sha256 = "180ys8ghm82l2l53wz3bhhjqjvrj4a2iv0xq66w9dbvsyw2mc863";
  };

  vendorSha256 = "1px1zzfihhdazaj31id1nxl6b09vy2yxj6wz5gv5f7mzdqdlmxxl";
}
