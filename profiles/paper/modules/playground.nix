{ config, pkgs, ... }:

{
  programs.fish.functions = {
    playground = {
      description = "Enter Playground DevOps shell";
      body = ''
        nix develop $HOME/sccl_nix#playground --command fish \
          -C "echo '    Playground shell activated'; \
              echo '    kubectl, helm, minikube, k9s...'; \
              echo '    type exit to return to paper'"
      '';
    };
  };
}
