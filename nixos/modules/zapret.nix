{ config, pkgs, inputs, ... }: {
    imports = [ inputs.zapret-discord-youtube.nixosModules.default ];

    services.zapret-discord-youtube = {
            enable = true;
            config = "general(ALT)";

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
}
