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
    minecraft = {
      enable = true;
      pierdolAuth = {
        version = "0.1.6";
        hash = "sha256-7x0TBeHO/7Z3ntbI4IWWvb36iBJjBtMxNLK3F7ZFsVc=";
      };
      pierdolChat = {
        version = "0.1.0";
        hash = "sha256-qse1y8KNuEbBs+9Ba+uygMNKtonCPz5R4zyWYHdD710=";
      };
      protocolLib = {
        version = "dev-build-2026-11-04";
        hash = "sha256-Tu1/czegIbj51qsReQumfBVluVEy2SSnx27v3hre03k=";
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
    vaultwarden = {
      enable = true;
    };
    mail = {
      enable = true;
      extraDomains = [ "pierdol.ing" ];
      outboundRelay.enable = true;
    };
    matrix = {
      enable = true;
      web = {
        enable = true;
      };
      discordBridge = {
        enable = true;
      };
    };
    discordBridge = {
      enable = true;
    };
    voice = {
      enable = true;
    };
    kanidm = {
      enable = true;
    };
    monitoring = {
      enable = true;
    };
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
      ];
    };
    backup = {
      enable = true;
      resticRepository = "s3:s3.amazonaws.com/backups-sccl";
    };
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
        "docker.io"
        "registry-1.docker.io"
        "production.cloudflare.docker.com"
        "telegram.org"
        "t.me"
        "telegram.me"
        "api.telegram.org"
        "web.telegram.org"
        "core.telegram.org"
      ];
      excludes = [];
    };
    sites = {
      enable = true;
      sites."sccl.cc" = {
        domain = "sccl.cc";
        extraDomains = [ "www.sccl.cc" ];
      };
      sites."bred.sccl" = {
        domain = "bred.sccl.cc";
        extraDomains = [ "shiza.sccl.cc" ];
        assetCacheControl = "no-cache";
      };
      sites."xkb.sccl" = {
        domain = "xkb.sccl.cc";
      };
      sites."otp-migrate" = {
        domain = "otp-migrate.sccl.cc";
      };
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
