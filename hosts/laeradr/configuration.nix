{ config, lib, pkgs, inputs, ... }:
{
  imports = [
    ./hardware-configuration.nix
    ./local-packages.nix
    ../../profiles/server/user.nix
  ];

  networking.hostName = "laeradr";

  services.nginx.virtualHosts."invite.pierdol.ing" = {
    forceSSL = true;
    sslCertificate = "/var/lib/acme/wildcard.pierdol.ing/fullchain.pem";
    sslCertificateKey = "/var/lib/acme/wildcard.pierdol.ing/key.pem";
    locations."/".return = "302 https://discord.gg/MNXnGGG3zt";
  };

  sccl = {
    boot.cachyos = false;
    secrets = {
      enable = true;
      user = "heimdall";
      scopes = [ "infra" "db" "apps" ];
    };
    server = {
      enable = true;
      domain = "sccl.cc";
      acmeEmail = "admin@sccl.cc";
    };
    dns = {
      enable = true;
      zone = "sccl.cc";
      # cf-proxied http only
      # offlineRedirect = "https://offline.sccl.cc/";
      extraZones = [
        (import ../../nixos/modules/server/dns-records-pierdolling.nix {
          domain = "pierdol.ing";
          serverIp = "192.168.0.10";
        } // { name = "pierdol.ing"; })
      ];
    };

    # opsec issue:
    wireguard = {
      enable = true;
      peers = [
        # { publicKey = "..."; allowedIPs = [ "10.100.0.2/32" ]; }
        { publicKey = "1OocjDwhGOeZrr2/OI+AMvq2nfuxwDYJoxbdBt6tdmc="; allowedIPs = [ "10.100.0.2/32" ]; } # aero15laptop
      ];
    };
    databases = {
      enable = true;
    };
    sftpgo = {
      enable = true;
    };
    forgejo = {
      enable = true;
    };
    gifs = {
      enable = true;
    };

    # writing full-blown workflows for my mods and pinning them here
    # was probably the WORST fucking idea i've ever had, but hey... it works and looks cool?
    minecraft = {
      enable = true;
      playersSleepingPercentage = 40;
      gsit = {
        version = "3.8.0";
        url = "https://cdn.modrinth.com/data/GOHbQGyX/versions/ybfOKLzp/GSit-3.8.0.jar";
        hash = "sha256-rGx1nPlgF2nkcVefn2UV5VjSWehdAGjyL5kWT03a4A8=";
      };
      inventoryRollbackPlus = {
        version = "1.8.5";
        url = "https://cdn.modrinth.com/data/XWKWAzd8/versions/eDsOfX6z/InventoryRollbackPlus-1.8.5.jar";
        hash = "sha256-hkgl+jT8KusQGJ+Hr7dn9BimwKMnhvJXcwxXhcqc8gU=";
      };
      pierdolAuth = {
        version = "0.1.7";
        hash = "sha256-egORPnkrIS9Byl24dMDkwNNnxPkmNmY/jtmC2FfF6eA=";
      };
      pierdolChat = {
        version = "0.1.6";
        hash = "sha256-0aaNWpuei/k691nH5Qw9n9jMdiZclbM38bN5cJDBBp4=";
      };
      pierdolPlaytime = {
        version = "0.1.4";
        hash = "sha256-IKtqYqkloAQdmXlo36EfcRveQyXOmEUqm+vIo9X+Ndc=";
      };
      protocolLib = {
        version = "dev-build-2026-11-04";
        hash = "sha256-Tu1/czegIbj51qsReQumfBVluVEy2SSnx27v3hre03k=";
      };
      placeholderApi = {
        version = "2.12.3";
        url = "https://cdn.modrinth.com/data/lKEzGugV/versions/pIvQcXW8/PlaceholderAPI-2.12.3.jar";
        hash = "sha256-/eAyWfWvaTjzwz7rTYFAAKGtq/HSMEzhSXC+gfYJpDc=";
      };
      interactiveChat = {
        version = "2026.1.3";
        url = "https://cdn.modrinth.com/data/VOenPQ01/versions/XMxzktgX/InteractiveChat-2026.1.3.0.jar";
        hash = "sha256-ihWaZUYBa4QV9PTVaTuPl9E1Wox+QhLct4zwu9Y17LA=";
      };
      vault = {
        version = "1.7.3";
        url = "https://github.com/MilkBowl/Vault/releases/download/1.7.3/Vault.jar";
        hash = "sha256-prXtl/Q6XPW7rwCnyM0jxa/JvQA/hJh1r4s25s930B0=";
      };
      fastLogin = {
        version = "1.21.11-26.20";
        hash = "sha256-sxVoz7e4gVCQ2ewDT5z315oue5HPZlAFy7/G7XCEDOs=";
      };
      invSee = {
        version = "0.31.22";
        hash = "sha256-AfPgU6gU921GUT6/ZaOHR98R34HFd9Er7RCLNT13dfk=";
      };
      tab = {
        version = "6.2.1";
        hash = "sha256-C2ohr2/TsRPAWCHartAP+SI0qEypSymzrsDvG9MTuKk=";
      };
      simpleAutoRestart = {
        version = "2.11.6";
        hash = "sha256-QJ5xiKfMxTflKpllC2Zs6RqTWxhPrps4/3InjF6m580=";
      };
      simpleVoiceChat = {
        version = "2.6.25";
        url = "https://cdn.modrinth.com/data/9eGKb6K1/versions/5OqsnSs7/voicechat-bukkit-2.6.25.jar";
        hash = "sha256-858uhAhzqgjgzOxzP9yCTtTDuSguAn/W8Yp5AG7rrSA=";
      };
      discordSrv = {
        channelId = "1574778983243845743";
        version = "1.30.5";
        url = "https://cdn.modrinth.com/data/UmLGoGij/versions/ATlquwiT/DiscordSRV-Build-1.30.5.jar";
        hash = "sha256-7y+h8usUbHx3QStxkKfdM/H8kSgmg/5FQHc5VUyK7+8=";
      };
      worldEdit = {
        version = "7.4.6";
        url = "https://cdn.modrinth.com/data/1u6JkXh5/versions/YFnqiUlL/worldedit-bukkit-7.4.6.jar";
        hash = "sha256-4M5n2HCtH++KQN2deSY2DK87tEciQ4VF1rILVfgqDJE=";
      };
      craftableInvFrames = {
        version = "2.4.2";
        url = "https://cdn.modrinth.com/data/wtE6hwEA/versions/VQC1vutJ/craftableinvframes-2.4.2.jar";
        hash = "sha256-4PLCROI1vby+7pPzj/nQy/vhBTLNIPVhWxIwlXqqoQc=";
        recipeIngredient = "GLOW_INK_SAC";
      };
      skinsRestorer = {
        version = "15.12.6";
        url = "https://github.com/SkinsRestorer/SkinsRestorer/releases/download/15.12.6/SkinsRestorer.jar";
        hash = "sha256-qFtKNw+Yh0HJo49NBJgmLtrL8yIDFHkKwcEnRhmWNZw=";
      };
      operators = [
        {
          uuid = "4af7fe6c-cb9e-4012-bef8-adf078f34694";
          name = "paper_sacculos";
          level = 4;
          bypassesPlayerLimit = true;
        }
      ];
    };
    # minePlatform.enable = false;
    minePlatform = {
      enable = true;
      sitePath = "/tank/sites/mine/public";

      adminDiscordIds = [
        "392014895429844993"
      ];

      moderatorDiscordIds = [ ];
    };

    murmur = {
      enable = true;
      channels = [ "Lounge" "Room 1" "Room 2" "Room 3" "Afk" ];
    };
    valheim = {
      enable = false;
      name = "ru::draumur::modded";
      world = "Midgard";
      worldModifiers = {
        resources = "muchmore";
        portals = "casual";
        deathPenalty = "casual";
        raids = "none";
      };
      rcon.enable = true;
      discord.enable = true;
      webmap.enable = true;
      qol = {
        passwordOnce = true;
        autoSaveInterval = true;
        idavoll.enable = true;
        idavoll.automatic = false;
        speedyPaths = true;
        quickStack = true;
        noStamCosts = true;
      };
      ui = {
        azuClock = true;
        comfyLadders = true;
        buildCamera = true;
        terrainer = true;
        configurationManager = true;
      };
      content = {
        epicLoot = true;
        plantEverything = true;
        protectiveWards = true;
        wearableTrophies = true;
        equipmentAndQuickSlots = true;
        craftFromChestsPlus = true;
        farmGridRemake = true;
        gizmo = true;
        odinHorse = true;
        planBuild = true;
        odinArchitect = true;
      };
      characters.enable = true;
      networking.enable = true;
      clientModpack.enable = true;
      clientModpack.version = "1.0.5";
      discordInvite = "https://discord.gg/MNXnGGG3zt";
      matrixRoom = "https://matrix.to/#/#draumur:pierdol.ing";
    };

    # i fucking love this thing,
    # i also host a second node on cloudflare using nodewarden, just in case.
    vaultwarden = {
      enable = true;
    };

    # asked my isp to unblock port 25, and they actually did.
    # still too fucking lazy to finish setting up my mail server
    # so i can actually send emails instead of just receiving them :D
    mail = {
      enable = true;
      extraDomains = [ "pierdol.ing" ];
      outboundRelay.enable = true;
    };

    # the whole idea of matrix is cool as fuck, federation and all that shit.
    # but first off, i've got nobody to talk to there,
    # and secondly, the current implementation and all the inconsistencies
    # in the specs are an absolute fucking mess.
    matrix = {
      enable = true;
      web = {
        enable = true;
      };
      # couldn't get this shit to work...
      # discord just keeps rate-limiting me and resetting my bots' tokens
      # no matter what the fuck i do ;k
      discordBridge = {
        enable = true;
      };
    };
    discordBridge = {
      enable = true;
    };

    # why the fuck do i even need voice calls in matrix if i've never used them???
    # they work like shit anyway.
    voice = {
      enable = true;
    };
    kanidm = {
      enable = true;
    };
    monitoring = {
      enable = true;
    };

    # couldn't decide whether to use grafana or gatus, so fuck it, i'm using both.
    # gatus is basically my public status page (tho if the whole server goes down, gatus goes down with it :D).
    #
    # i don't really like gatus, it's genuinely kinda shit.
    # can't customize it the way i want, but... it works, i guess.
    # too lazy to fuck around with alternatives rn??? don't even know many of them ;k
    status = {
      enable = true;
      endpoints = [
        { name = "main website"; group = "apps"; url = "https://sccl.cc"; interval = "3m"; }
        { name = "xkb generator"; group = "apps"; url = "https://xkb.sccl.cc"; interval = "5m"; }
        { name = "google otp migration decoder"; group = "apps"; url = "https://otp-migrate.sccl.cc"; interval = "5m"; }
        { name = "gif.sccl api"; group = "apps"; url = "https://gif.sccl.cc/api/health"; interval = "1m"; }
        { name = "matrix"; group = "services"; url = "https://pierdol.ing/_matrix/client/versions"; interval = "5m"; }
        { name = "pierdol ing"; group = "apps"; url = "https://pierdol.ing"; interval = "5m"; }
        { name = "postgresql"; group = "services"; url = "tcp://127.0.0.1:5432"; interval = "1m"; conditions = [ "[CONNECTED] == true" "[RESPONSE_TIME] < 2000" ]; }
        { name = "sftpgo"; group = "services"; url = "https://files.sccl.cc"; interval = "5m"; }
        { name = "forgejo"; group = "services"; url = "https://git.sccl.cc"; interval = "5m"; }
        { name = "vaultwarden"; group = "services"; url = "https://pass.sccl.cc"; interval = "5m"; }
        { name = "stalwart"; group = "services"; url = "https://webmail.sccl.cc"; interval = "5m"; }
        { name = "prometheus"; group = "monitoring"; url = "https://prometheus.sccl.cc/-/healthy"; interval = "5m"; }
        { name = "grafana"; group = "monitoring"; url = "https://grafana.sccl.cc/api/health"; interval = "5m"; }
        { name = "loki"; group = "monitoring"; url = "https://loki.sccl.cc/ready"; interval = "5m"; }
        { name = "alertmanager"; group = "monitoring"; url = "https://alertmanager.sccl.cc/-/healthy"; interval = "5m"; }
        { name = "comments api"; group = "apps"; url = "https://comments.pierdol.ing/health"; interval = "1m"; }
        { name = "searxng"; group = "services"; url = "https://sx.pierdol.ing/healthz"; interval = "5m"; }
        { name = "valheim"; group = "games"; url = "http://127.0.0.1:${toString config.sccl.valheim.webmap.port}/"; interval = "1m"; }
        { name = "mine.pierdol.ing core"; group = "games"; url = "https://mine.pierdol.ing/api/v1/healthz"; interval = "5m"; }
        { name = "mine skyblock server"; group = "games"; url = "tcp://127.0.0.1:25565"; interval = "1m"; conditions = [ "[CONNECTED] == true" ]; }
      ];
    };
    backup = {
      enable = true;
      resticRepository = "s3:s3.amazonaws.com/backups-sccl";
    };

    # this shit is actually more convenient than obsidian,
    # just haven't gotten around to making it really fucking cool
    # and tweaking it to fit my workflow yet.
    silverbullet.enable = true;
    proxy = {
      enable = true;
      sites = {
        git = {
          upstream = "http://10.69.0.10:3000";
          extraConfig = ''
            client_max_body_size 200m;
          '';
        };
      };
    };
    zapret = {
      enable = true;
      # i love Flowseal :heart_eyes:
      # general.bat tcp profile
      extraTcpProfiles = let
        clientHello = pkgs.fetchurl {
          url = "https://raw.githubusercontent.com/Flowseal/zapret-discord-youtube/cf018db758623ed1813b9d93a6d7f3bdf01cc2b4/bin/tls_clienthello_4pda_to.bin";
          hash = "sha256-7v6vCd3o1psfF2ISVB9jxosxSjOjNeztmaiinxclTag=";
        };
      in [
        [
          "--filter-tcp=443"
          "--hostlist-domains=discord.com,discord.gg,discordapp.com,discordapp.net,discord.media,discordvoice.com"
          "--dpi-desync=multisplit"
          "--dpi-desync-split-seqovl=568"
          "--dpi-desync-split-pos=1"
          "--dpi-desync-split-seqovl-pattern=${clientHello}"
        ]
      ];
      tcpStrategy = [
        "--dpi-desync=fake"
        "--dpi-desync-fooling=badseq"
        "--dpi-desync-repeats=6"
        # pin the tested fake SNI
        "--dpi-desync-fake-tls-mod=rnd,dupsid,sni=qn9zubc2cj3zz.biz"
      ];
      hosts = [
        "discord.com"
        "discord.gg"
        "discordapp.com"
        "discordapp.net"
        "media.discordapp.net"
        "cdn.discordapp.com"
        "discord.media"
        "discordvoice.com"
        "api.cloudflare.com"
        "ziglang.org" # putin blocks ziglang :D
        "telegram.org"
        "t.me"
        "telegram.me"
        "api.telegram.org"
        "web.telegram.org"
        "core.telegram.org"
      ];
      excludes = [
        "docker.io"
        "docker.com"
      ];
    };
    sites = {
      enable = true;

      # some random asshole's website
      sites."sccl.cc" = {
        domain = "sccl.cc";
        extraDomains = [ "www.sccl.cc" ];
      };

      # some fucking blog... why the fuck do i even post there??
      sites."bred.sccl" = {
        domain = "bred.sccl.cc";
        extraDomains = [ "shiza.sccl.cc" ];
        assetCacheControl = "no-cache";
      };

      # xkb config generator, literally used it ONCE.
      sites."xkb.sccl" = {
        domain = "xkb.sccl.cc";
      };

      # otp keys generator, literally used it ONCE.
      sites."otp-migrate" = {
        domain = "otp-migrate.sccl.cc";
      };

      # gifs or webms or whatever, kinda janky.
      sites."gif.sccl" = {
        domain = "gif.sccl.cc";
        facade = {
          upstream = "http://127.0.0.1:8083";
          apiPrefix = "/api";
          extraConfig = ''
            client_max_body_size 25m;
            proxy_read_timeout 60s;
          '';
        };
      };
    };
    mirror = {
      enable = true;
    };
    comments = {
      enable = true;
    };
    macc = {
      enable = true;
    };
    searxng = {
      enable = true;
    };
  };

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    users.heimdall = import ../../profiles/server/home.nix;
  };

  system.stateVersion = "26.05";
}
