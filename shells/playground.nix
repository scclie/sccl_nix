{ pkgs }:

pkgs.mkShell {
  packages = with pkgs; [
    kubectl krew minikube kubernetes-helm k9s stern popeye
    dive lazydocker docker-compose
    prometheus grafana
    postgresql
    kind yq-go jq
  ];

  shellHook = ''
    echo "Playground shell — type 'exit' to return"
  '';
}
