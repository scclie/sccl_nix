{ config, lib, pkgs, inputs, ... }: {
    imports = [ inputs.zapret-discord-youtube.nixosModules.default ];

    services.zapret-discord-youtube = {
            enable = true;
            configName = "general (FAKE_TLS_AUTO)";
            gameFilter = "all";

            listGeneral = [
            # discord
            "discord.com" "discord.gg" "discordapp.com" "discordapp.net" "media.discordapp.net" "discord.media" "discordvoice.com"
            # container registries
            "docker.io" "registry-1.docker.io" "registry-2.docker.io" "production.cloudflare.docker.com"
            "gcr.io" "k8s.gcr.io" "registry.k8s.io" "quay.io" "ghcr.io"
            ];

            listExclude = [
                # Github
                "github.com" "githubusercontent.com" "api.github.com" "octocaptcha.com"
                "githubassets.com" "github.blog" "github.dev" "github.status"
                "ghcr.io" "objects.githubusercontent.com"

                # NixOs
                "nixos.org" "channels.nixos.org" "cache.nixos.org" "nix-community.cachix.org"
                "hydra.nixos.org" "status.nixos.org" "search.nixos.org"

                # Steam
                "steampowered.com" "steamcommunity.com" "steamgames.com" "steamcontent.com"
                "steam-chat.com" "steamstatic.com" "steampowered.com.edgesuite.net" "akamaihd.net"

                # Rust
                "crates.io"

                # Zed
                "api.zed.dev" "zed.dev" "zed-extensions.nyc3.digitaloceanspaces.com" "digitaloceanspaces.com" "doubleclick.githubusercontent"
            ];

            ipsetAll = [ "192.168.1.0/24" "10.0.0.1" ];
            ipsetExclude = [ "203.0.113.0/24" "172.66.165.132" "104.20.29.242"];
    };

    # Rust game server uses Raknet on UDP 1337 — not covered by zapret's
    # NFQWS_PORTS_UDP (443,50000-65535). Route it through nfqws manually.
    systemd.services.zapret-discord-youtube.postStart = lib.mkAfter ''
      sleep 1
      iptables -t mangle -C POSTROUTING -p udp --dport 1337 -m connbytes --connbytes-dir=original --connbytes-mode=packets --connbytes 1:9 -m mark ! --mark 0x40000000/0x40000000 -m set ! --match-set nozapret dst -j NFQUEUE --queue-num 200 --queue-bypass 2>/dev/null || \
      iptables -t mangle -A POSTROUTING -p udp --dport 1337 -m connbytes --connbytes-dir=original --connbytes-mode=packets --connbytes 1:9 -m mark ! --mark 0x40000000/0x40000000 -m set ! --match-set nozapret dst -j NFQUEUE --queue-num 200 --queue-bypass
    '';
}
