{ config, lib, pkgs, ... }:

let
  cfg = config.sccl.searxng;
  domain = "pierdol.ing";
  searchDomain = "sx.${domain}";
  themeCss = ./searx-nord.css;
in {
  options.sccl.searxng = {
    enable = lib.mkEnableOption "SearXNG metasearch on search.pierdol.ing";
  };

  config = lib.mkIf cfg.enable {
    # cookie secret
    sops.secrets."searxng/secret-key" = {
      sopsFile = ../../../../secrets/apps.yaml;
      mode = "0400";
    };

    sops.templates."searxng-env" = {
      content = ''
        SEARXNG_SECRET_KEY=${config.sops.placeholder."searxng/secret-key"}
      '';
      path = "/etc/nixos/secrets/searxng-env";
      mode = "0400";
    };

    services.searx = {
      enable = true;
      configureUwsgi = true;
      redisCreateLocally = true;
      environmentFile = config.sops.templates."searxng-env".path;

      uwsgiConfig.http = "127.0.0.1:8094";

      settings = {
        use_default_settings = true;
        server = {
          port = 8094;
          bind_address = "127.0.0.1";
          base_url = "https://${searchDomain}/";
          secret_key = "$SEARXNG_SECRET_KEY";
          limiter = false;
          public_instance = false;
          method = "GET";
        };
        ui = {
          default_locale = "en";
          theme_args.simple_style = "dark";
        };
      };
    };


    systemd.services.searx-init = {
      after = lib.mkAfter [ "sops-install-secrets.service" ];
      wants = [ "sops-install-secrets.service" ];
    };

    # per-ip rate limit for the whole searx vhost
    services.nginx.appendHttpConfig = ''
      limit_req_zone $binary_remote_addr zone=searx:10m rate=5r/s;
    '';

    services.nginx.virtualHosts."${searchDomain}" = {
      forceSSL = true;
      sslCertificate = "/var/lib/acme/wildcard.${domain}/fullchain.pem";
      sslCertificateKey = "/var/lib/acme/wildcard.${domain}/key.pem";

      locations = {
        "= /nord.css" = {
          alias = "${themeCss}";
          extraConfig = ''
            default_type text/css;
            add_header Cache-Control "public, max-age=86400";
          '';
        };
        "/" = {
          proxyPass = "http://127.0.0.1:8094";
          proxyWebsockets = true;
          extraConfig = ''
            proxy_set_header Accept-Encoding "";
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            limit_req zone=searx burst=20 nodelay;

            sub_filter '</head>' '<style>
              :root.theme-dark {
                --color-base-background: #2e3440 !important;
                --color-base-background-mobile: #2e3440 !important;
                --color-base-font: #d8dee9 !important;
                --color-header-background: #3b4252 !important;
                --color-footer-background: #3b4252 !important;
                --color-footer-border: #434c5e !important;
              }
              * { border-radius: 0 !important; }
            </style></head>';
            sub_filter_once on;
            sub_filter_types text/html;
          '';
        };
      };
    };
  };
}
