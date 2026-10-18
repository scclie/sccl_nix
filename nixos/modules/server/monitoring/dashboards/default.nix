{ runCommand, fetchFromGitHub, go-jsonnet, jq }:

let
  grafonnet = fetchFromGitHub {
    owner = "grafana";
    repo = "grafonnet";
    rev = "41e6bfcbe4ef1054298ffff8664f1354c897dd2d";
    hash = "sha256-TZ0+tcWEPuOTM4vt3V+gz7KJRLbHqnHserMoaEivlyM=";
  };
  docsonnet = fetchFromGitHub {
    owner = "jsonnet-libs";
    repo = "docsonnet";
    rev = "bf6f08ae02a51c48bdcec4629b1c1a5a62c6f803";
    hash = "sha256-F9QF0WOZYfMeOIO+Z9KzPziajvf7vsVz4MGAJkyoQuQ=";
  };
  xtd = fetchFromGitHub {
    owner = "jsonnet-libs";
    repo = "xtd";
    rev = "4d7f8cb24d613430799f9d56809cc6964f35cea9";
    hash = "sha256-MWinI7gX39UIDVh9kzkHFH6jsKZoI294paQUWd/4+ag=";
  };
in runCommand "infrastructure-dashboards" {
  nativeBuildInputs = [ go-jsonnet jq ];
} ''
  mkdir -p vendor/github.com/grafana vendor/github.com/jsonnet-libs "$out"
  ln -s ${grafonnet} vendor/github.com/grafana/grafonnet
  ln -s ${docsonnet} vendor/github.com/jsonnet-libs/docsonnet
  ln -s ${xtd} vendor/github.com/jsonnet-libs/xtd
  jsonnet -J vendor ${./host.jsonnet} > "$out/host.json"
  jsonnet -J vendor ${./logs.jsonnet} > "$out/logs.json"
  jq -e '.uid == "sccl-host" and (.panels | length > 20)' "$out/host.json" > /dev/null
  jq -e '.uid == "sccl-logs" and (.panels | length == 2)' "$out/logs.json" > /dev/null
''
