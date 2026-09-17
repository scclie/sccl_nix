{ config, lib, pkgs, ... }:
let
  cfg = config.sccl.matrix;
  wellKnownServer = pkgs.writeText "matrix-server-wk" ''{"m.server": "pierdol.ing:443"}'';
  wellKnownClient = pkgs.writeText "matrix-client-wk" ''{"m.homeserver": {"base_url": "https://pierdol.ing"}}'';
  elementConfigFile = pkgs.writeText "element-config.json" (builtins.toJSON {
    default_server_config = {
      "m.homeserver" = { base_url = "https://pierdol.ing"; server_name = "pierdol.ing"; };
    };
    room_directory = { servers = [ "pierdol.ing" "matrix.org" ]; };
    brand = "pierdol.ing";
    default_country_code = "RU";
    show_labs_settings = false;
  });
in {
  options.sccl.matrix = {
    enable = lib.mkEnableOption "Matrix homeserver (continuwuity) + pierdol.ing web host";
    domain = lib.mkOption {
      type = lib.types.str;
      default = "pierdol.ing";
      description = "Matrix server_name. IMMUTABLE once the first user is registered.";
    };
    web = {
      enable = lib.mkEnableOption "element-web browser client on chat.<domain>";
      subdomain = lib.mkOption {
        type = lib.types.str;
        default = "chat";
      };
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
          "/" = {
            tryFiles = "$uri $uri/ =404";
          };
        };
      };

      # federation (server-to-server) listener; same upstream as client api.
      # ssl cert emitted via extraConfig: with a custom listen list NixOS
      # skips ssl_certificate unless addSSL/forceSSL (and addSSL would also
      # open a 443 listener under the same server_name - collision with apex)
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

      # element-web: browser matrix client; anyone can log in with any
      # matrix account (homeserver prefilled but switchable in the login ui)
      "chat.${cfg.domain}" = lib.mkIf cfg.web.enable {
        addSSL = true;
        root = "${pkgs.element-web}/share/element-web";
        sslCertificate = "/var/lib/acme/wildcard.${cfg.domain}/fullchain.pem";
        sslCertificateKey = "/var/lib/acme/wildcard.${cfg.domain}/key.pem";
        locations = {
          "= /config.json" = {
            alias = "${elementConfigFile}";
            extraConfig = ''
              default_type application/json;
            '';
          };
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
      };

      config = { config, lib, pkgs, ... }: {
        system.stateVersion = "26.05";

        services.matrix-continuwuity = {
          enable = true;
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
              # federation delegated to 443: cloudflare does not proxy 8448
              server = "pierdol.ing:443";
            };
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
