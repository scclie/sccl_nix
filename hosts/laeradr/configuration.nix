{ config, lib, pkgs, inputs, ... }:
{
  imports = [
    ./hardware-configuration.nix
    ./local-packages.nix
    ../../profiles/server/user.nix
  ];

  networking.hostName = "laeradr";

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
      extraZones = [
        (import ../../nixos/modules/server/dns-records-pierdolling.nix {
          serverIp = "192.168.0.10";
        } // { name = "pierdol.ing"; })
      ];
    };
    wireguard = {
      enable = true;
      peers = [
        # { publicKey = "..."; allowedIPs = [ "10.100.0.2/32" ]; }
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
    murmur = {
      enable = true;
      channels = [ "Lounge" "Room 1" "Room 2" "Room 3" "Afk" ];
    };
    valheim = {
      enable = false;
      name = "laeradr";
      world = "Midgard";
    };
    vaultwarden = {
      enable = true;
    };
    mail = {
      enable = true;
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
        { name = "maddy"; group = "services"; url = "https://mail.sccl.cc"; interval = "5m"; }
        { name = "prometheus"; group = "monitoring"; url = "https://prometheus.sccl.cc/-/healthy"; interval = "5m"; }
        { name = "grafana"; group = "monitoring"; url = "https://grafana.sccl.cc/api/health"; interval = "5m"; }
        { name = "loki"; group = "monitoring"; url = "https://loki.sccl.cc/ready"; interval = "5m"; }
        { name = "alertmanager"; group = "monitoring"; url = "https://alertmanager.sccl.cc/-/healthy"; interval = "5m"; }
        { name = "comments api"; group = "apps"; url = "https://comments.pierdol.ing/health"; interval = "1m"; }
        { name = "searxng"; group = "services"; url = "https://sx.pierdol.ing/healthz"; interval = "5m"; }
      ];
    };
    backup = {
      enable = true;
      resticRepository = "s3:s3.amazonaws.com/backups-sccl";
    };
    proxy = {
      enable = true;
      sites = {
        git = { upstream = "http://10.69.0.10:3000"; };
        # pass / pass-api are registered by the vaultwarden module itself
      };
    };
    zapret = {
      enable = true;
      hosts = [
        "discord.com"
        "discord.gg"
        "discordapp.com"
        "discordapp.net"
        "media.discordapp.net"
        "cdn.discordapp.com"
        "discord.media"
        "discordvoice.com"
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
            proxy_set_header Host $host;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header CF-Connecting-IP $http_cf_connecting_ip;
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

  # mautrix-discord pulls libolm 3.2.16 (deprecated upstream, no maintained
  # fix); used only when a bridge session enables E2EE - acceptable here
  nixpkgs.config.permittedInsecurePackages = [ "olm-3.2.16" "kanidm-with-secret-provisioning-1.8.6" ];

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    users.heimdall = import ../../profiles/server/home.nix;
  };

  system.stateVersion = "26.05";
}
