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

      update = "cd ~/sccl_nix/ && sudo nix flake update";
      clean = "sudo nix-collect-garbage -d";

      ".." = "cd ..";
      "..." = "cd ../..";
    };

    functions = {
      fish_greeting = "";
      rebuild = {
        argumentNames = "host";
        body = "sudo nixos-rebuild switch --flake ~/sccl_nix/#$host";
      };
      rebuildproxy = {
        argumentNames = "host";
        body = "sudo env http_proxy=http://127.0.0.1:7890 https_proxy=http://127.0.0.1:7890 nixos-rebuild switch --flake ~/sccl_nix/#$host";
      };
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
