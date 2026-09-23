{ config, lib, pkgs, ... }:
let
  cfg = config.sccl.matrix;
  discordBridgeOn = cfg.discordBridge.enable && config.sccl.discordBridge.enable;
  # oidc delegated auth to kanidm (id.pierdol.ing); kept for re-enabling oidc,
  # currently unused (sso dropped for matrix 2026-09-22)
  # kanidmOn = config.sccl.kanidm.enable;
  # pinned upstream continuwuity: nixpkgs still ships 0.5.10, which lacks
  # delegated OIDC
  # use the project's prebuilt static binary instead
  continuwuity = pkgs.stdenvNoCC.mkDerivation {
    pname = "matrix-continuwuity";
    version = "26.9.0";
    src = pkgs.fetchurl {
      url = "https://forgejo.ellis.link/continuwuation/continuwuity/releases/download/v26.9.0/conduwuit-linux-static-amd64";
      hash = "sha256-qQmDzu18G53LTrK/VP5UcS+mGs4F40RRuCRrax3r+k0=";
    };
    dontUnpack = true;
    installPhase = "install -Dm755 $src $out/bin/conduwuit";
    meta.mainProgram = "conduwuit";
  };
  wellKnownServer = pkgs.writeText "matrix-server-wk" ''{"m.server": "pierdol.ing:443"}'';
  # msc2965 m.authentication (element -> kanidm oauth) removed 2026-09-22:
  # matrix dropped out of SSO, clients use plain password login again.
  wellKnownClient = pkgs.writeText "matrix-client-wk" (builtins.toJSON {
    "m.homeserver" = { base_url = "https://pierdol.ing"; };
    "org.matrix.msc4143.rtc_foci" = [{ type = "livekit"; livekit_service_url = "https://livekit.pierdol.ing"; }];
  });
  cinnyConfigFile = pkgs.writeText "cinny-config.json" (builtins.toJSON {
    defaultHomeserver = 0;
    homeserverList = [ "https://pierdol.ing" ];
    allowCustomHomeservers = false;
  });
  cinnyNordCss = ./cinny-nord.css;
in {
  options.sccl.matrix = {
    enable = lib.mkEnableOption "Matrix homeserver (continuwuity) + pierdol.ing web host";
    domain = lib.mkOption {
      type = lib.types.str;
      default = "pierdol.ing";
      description = "Matrix server_name. IMMUTABLE once the first user is registered.";
    };
    web = {
      enable = lib.mkEnableOption "cinny browser client on chat.<domain>";
      subdomain = lib.mkOption {
        type = lib.types.str;
        default = "chat";
      };
    };
    discordBridge = {
      enable = lib.mkEnableOption "discord bridge tenant vhost";
    };
  };

  config = lib.mkIf cfg.enable {
    # reuses the cloudflare-acme env template + nginx/acme wiring from sccl.proxy
    security.acme.certs."wildcard.${cfg.domain}" = {
      domain = "*.${cfg.domain}";
      extraDomainNames = [ cfg.domain ];
      dnsProvider = "cloudflare";
      environmentFile = "/etc/nixos/secrets/cloudflare-acme.env";
    };

    # meme layout deploys from CI via releases symlinks; /videos/ lives
    # outside the swap on the sites dataset (rsync'ed by hand)
    systemd.tmpfiles.rules = [
      "d /tank/sites/pierdol/files/videos 0755 root root -"
    ];

    services.nginx.virtualHosts = {
      "pierdol.ing" = {
        addSSL = true;
        root = "/tank/sites/pierdol/public";
        sslCertificate = "/var/lib/acme/wildcard.${cfg.domain}/fullchain.pem";
        sslCertificateKey = "/var/lib/acme/wildcard.${cfg.domain}/key.pem";
        locations = {
          "= /.well-known/matrix/server" = {
            alias = "${wellKnownServer}";
            extraConfig = ''
              default_type application/json;
              add_header Access-Control-Allow-Origin *;
            '';
          };
          "= /.well-known/matrix/client" = {
            alias = "${wellKnownClient}";
            extraConfig = ''
              default_type application/json;
              add_header Access-Control-Allow-Origin *;
            '';
          };
          "^~ /videos/" = {
            alias = "/tank/sites/pierdol/files/videos/";
            extraConfig = ''
              autoindex on;
              autoindex_format json;
              types {
                video/mp4 mp4;
                video/webm webm;
              }
            '';
          };
          "/_matrix/" = {
            proxyPass = "http://10.69.0.19:6167";
            extraConfig = ''
              client_max_body_size 25m;
              proxy_read_timeout 600s;
            '';
          };
          # OAuth / account endpoints of continuwuity, only relevant with OIDC
          # (kanidm) wired; disabled since matrix dropped SSO (2026-09-22)
          # "/_continuwuity/" = lib.mkIf kanidmOn {
          #   proxyPass = "http://10.69.0.19:6167";
          #   extraConfig = ''
          #     client_max_body_size 25m;
          #     proxy_read_timeout 600s;
          #   '';
          # };
          "/" = {
            tryFiles = "$uri $uri/ =404";
          };
        };
      };

      # federation (server-to-server) listener; same upstream as client api.
      # ssl cert emitted via extraConfig: with a custom listen list nixos
      # skips ssl_certificate unless addSSL/forceSSL (and addSSL would also open a 443 listener under the same server_name - collision with apex)
      "matrix-federation" = {
        serverName = cfg.domain;
        listen = [ { addr = "0.0.0.0"; port = 8448; ssl = true; } ];
        extraConfig = ''
          ssl_certificate /var/lib/acme/wildcard.${cfg.domain}/fullchain.pem;
          ssl_certificate_key /var/lib/acme/wildcard.${cfg.domain}/key.pem;
        '';
        locations."/" = {
          proxyPass = "http://10.69.0.19:6167";
          extraConfig = ''
            client_max_body_size 25m;
            proxy_read_timeout 600s;
          '';
        };
      };

      # cinny browser matrix client; anyone can log in with any matrix acc
      "chat.${cfg.domain}" = lib.mkIf cfg.web.enable {
        addSSL = true;
        root = "${pkgs.cinny}";
        sslCertificate = "/var/lib/acme/wildcard.${cfg.domain}/fullchain.pem";
        sslCertificateKey = "/var/lib/acme/wildcard.${cfg.domain}/key.pem";
        locations = {
          "= /config.json" = {
            alias = "${cinnyConfigFile}";
            extraConfig = ''
              default_type application/json;
            '';
          };
          "= /nord.css" = {
            alias = "${cinnyNordCss}";
            extraConfig = ''
              default_type text/css;
              add_header Cache-Control "public, max-age=86400";
            '';
          };
          "= /index.html" = {
            alias = "${pkgs.cinny}/index.html";
            extraConfig = ''
              sub_filter '</head>' '<link rel="stylesheet" href="/nord.css"></head>';
              sub_filter_once on;
              sub_filter_types text/html;
            '';
          };
          "/" = {
            index = "index.html";
            tryFiles = "$uri $uri/ /index.html";
            extraConfig = ''
              sub_filter '</head>' '<link rel="stylesheet" href="/nord.css"></head>';
              sub_filter_once on;
              sub_filter_types text/html;
            '';
          };
        };
      };

      # mautrix-discord web ui helper, proxied to the host bridge listener
      "discord-bridge.${cfg.domain}" = lib.mkIf discordBridgeOn {
        addSSL = true;
        sslCertificate = "/var/lib/acme/wildcard.${cfg.domain}/fullchain.pem";
        sslCertificateKey = "/var/lib/acme/wildcard.${cfg.domain}/key.pem";
        locations."/" = {
          proxyPass = "http://127.0.0.1:29334";
          proxyWebsockets = true;
          extraConfig = ''
            client_max_body_size 25m;
          '';
        };
      };
    };

    environment.etc."resolv.conf.matrix-ct".text = ''
      nameserver 1.1.1.1
      nameserver 8.8.8.8
      options edns0 trust-ad
    '';

    containers.matrix-ct = {
      autoStart = true;
      ephemeral = true;
      privateNetwork = true;
      hostAddress = "10.69.0.1";
      localAddress = "10.69.0.19";
      hostBridge = "br-svc";

      bindMounts = {
        "/var/lib/continuwuity" = {
          hostPath = "/tank/matrix";
          isReadOnly = false;
        };
        "/etc/resolv.conf" = {
          hostPath = "/etc/resolv.conf.matrix-ct";
          isReadOnly = true;
        };
      # sops-rendered client secret for OIDC; dead with SSO off (2026-09-22)
        # } // (lib.optionalAttrs kanidmOn {
        #   "/run/continuwuity-oidc.env" = {
        #     hostPath = config.sops.templates."continuwuity-oidc.env".path;
        #     isReadOnly = true;
        #   };
        # });
      };

      config = { config, lib, pkgs, ... }: {
        system.stateVersion = "26.05";

        services.matrix-continuwuity = {
          enable = true;
          package = continuwuity;
          settings.global = {
            server_name = "${cfg.domain}";
            address = [ "10.69.0.19" ];
            port = [ 6167 ];
            allow_registration = false;
            allow_encryption = true;
            allow_federation = true;
            trusted_servers = [ "matrix.org" ];
            max_request_size = 25165824; # match nginx 25m
            well_known = {
              client = "https://pierdol.ing";
              server = "pierdol.ing:443";
            };

            matrix_rtc.foci = [{
              type = "livekit";
              livekit_service_url = "https://livekit.pierdol.ing";
            }];
          # OIDC delegated auth to kanidm disabled 2026-09-22 (password login):
            # } // (lib.optionalAttrs kanidmOn {
            #
            #   oauth.oidc = {
            #     discovery_url = "https://id.pierdol.ing/oauth2/openid/continuwuity";
            #     client_id = "continuwuity";
            #   };
            # });
          };
        };

        # bind mount is the sole state dir: dynamic user can't own it (random
        # uid), so pin a static uid/gid, run as that user and grant perms via
        # container tmpfiles (Z walks the dataset through the mount)
        users.users.continuwuity = {
          isSystemUser = true;
          uid = 930;
          group = "continuwuity";
        };
        users.groups.continuwuity = { gid = 930; };
        systemd.services.continuwuity = {
          serviceConfig = {
            DynamicUser = lib.mkForce false;
            StateDirectory = lib.mkForce "";
            ReadWritePaths = [ "/var/lib/continuwuity" ];
            # EnvironmentFile = lib.mkIf kanidmOn "/run/continuwuity-oidc.env";
          };
        };
        systemd.tmpfiles.rules = [
          "Z /var/lib/continuwuity 0700 continuwuity continuwuity"
        ];

        networking.firewall.allowedTCPPorts = [ 6167 ];
      };
    };
  };
}
