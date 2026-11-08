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
      rebuild-home = {
        argumentNames = "host";
        body = ''
          set -l activation (nix build --no-link --print-out-paths "$HOME/sccl_nix#nixosConfigurations.$host.config.home-manager.users.$USER.home.activationPackage")
          or return $status

          "$activation/activate"
        '';
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

      # fzf shortcuts
      for mode in default insert
        bind --erase -M $mode \ec
        bind --erase -M $mode \cr
        bind -M $mode \ed fzf-cd-widget           # ctlr + x
        bind -M $mode \cx fzf-history-widget      # alt + d
      end

      # delete words (left-right)
      for mode in default insert
        bind -M $mode \en backward-kill-word      # alt + n
        bind -M $mode \ei kill-word               # alt + i
      end
    '';
  };
}
