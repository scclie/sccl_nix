{ config, pkgs, ... }:

{
  programs.fish = {
    enable = true;

    shellAliases = {
      ls = "eza --icons";
      ll = "eza -l --icons";
      la = "eza -la --icons";
      tree = "eza --tree --icons";

      cat = "bat";

      rebuild = "sudo nixos-rebuild switch --flake ~/sccl_nix/#sacculos";
      rebuildproxy = "sudo env http_proxy=http://127.0.0.1:7890 https_proxy=http://127.0.0.1:7890 nixos-rebuild switch --flake ~/sccl_nix/#sacculos";
      update = "cd ~/sccl_nix/ && sudo nix flake update && rebuild";
      clean = "sudo nix-collect-garbage -d";

      ".." = "cd ..";
      "..." = "cd ../..";
    };

    functions = {
      fish_greeting = "";
    };

    interactiveShellInit = ''
      set fish_greeting

      # Zoxide
      zoxide init fish | source

      # FZF
      fzf --fish | source
    '';
  };
}
