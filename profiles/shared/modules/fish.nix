{ config, pkgs, ... }:

{
  programs.fish = {
    enable = true;

    shellAliases = {
      # i think replacing basic utils with aliases might be a shitty idea...
      # sometimes eza's fancy bullshit makes copying output butthurt.
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

      # am too lazy to write out the entire switch flake... this is just more convenient
      rebuild = {
        argumentNames = "host";
        body = "sudo nixos-rebuild switch --flake ~/sccl_nix/#$host";
      };

      # bruh, why the fuck is it that if i successfully rebuild my system
      # but fuck up the network config and completely lose internet access,
      # i can't just manually fix it in `/nix/store` because it's fucking read-only,
      # and i can't rebuild the system again bc the fucking rebuild insists
      # on reaching out to `cache.nixos.org` AND I HAVE NO FUCKING INTERNET.
      # whatever, fuck it, this alias can just come in handy sometimes.
      rebuild-offline = {
        argumentNames = "host";
        body = "sudo nixos-rebuild switch --offline --option substitute false --flake ~/sccl_nix/#$host";
      };
      # anyway...
      # why the fuck am i routing all my traffic through `mihomo.service`?
      # mb this is an architectural mistake, and i should rethink this part...


      # ngl, i barely ever use this alias...
      # might be useful tho? idk, never really figured out
      # how to use home manager properly, so it's kinda scuffed
      # on my setup. easier to just rebuild the whole damn thing
      # than fuck around with this shit.
      rebuild-home = {
        argumentNames = "host";
        body = ''
          set -l activation (nix build --no-link --print-out-paths "$HOME/sccl_nix#nixosConfigurations.$host.config.home-manager.users.$USER.home.activationPackage")
          or return $status

          "$activation/activate"
        '';
      };

      # used to run this back when i was using flclashx,
      # but now i'm in tun-mode 24/7, so this shit is pretty much useless
      rebuild-proxy = {
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
