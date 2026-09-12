{ config, lib, ... }:
let
  cfg = config.sccl.sites;
  serverCfg = config.sccl.server;
in {
  options.sccl.sites = {
    enable = lib.mkEnableOption "static site hosting from /tank/sites";
    sites = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule {
        options = {
          domain = lib.mkOption {
            type = lib.types.str;
            description = "Primary vhost hostname";
          };
          extraDomains = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [];
            description = "Additional hostnames serving the same root";
          };
          facade = lib.mkOption {
            type = lib.types.nullOr (lib.types.submodule {
              options = {
                upstream = lib.mkOption { type = lib.types.str; };
                apiPrefix = lib.mkOption {
                  type = lib.types.str;
                  default = "/api";
                };
                extraConfig = lib.mkOption {
                  type = lib.types.str;
                  default = "";
                  description = "Extra location configuration (e.g. client_max_body_size)";
                };
              };
            });
            default = null;
            description = "Optional backend proxy for dynamic routes (reserved for the DB-era)";
          };
        };
      });
      default = {};
    };
  };

  config = lib.mkIf cfg.enable {
    services.nginx.virtualHosts = lib.mapAttrs' (name: site:
      lib.nameValuePair name ({
        serverName = lib.concatStringsSep " " ([ site.domain ] ++ site.extraDomains);
        root = "/tank/sites/${name}/public";
        addSSL = true;
        sslCertificate = "/var/lib/acme/wildcard.${serverCfg.domain}/fullchain.pem";
        sslCertificateKey = "/var/lib/acme/wildcard.${serverCfg.domain}/key.pem";
        locations = lib.mkMerge ([
          {
            "/" = {
              tryFiles = "$uri $uri/ =404";
              extraConfig = ''
                add_header Cache-Control "no-cache";
              '';
            };
            "~* \.(?:css|js|woff2?|ttf|png|jpg|jpeg|gif|svg|webp|avif|ico)$" = {
              tryFiles = "$uri =404";
              extraConfig = ''
                add_header Cache-Control "public, max-age=31536000, immutable";
              '';
            };
          }
        ] ++ lib.optional (site.facade != null) {
          "^~ ${site.facade.apiPrefix}" = {
            proxyPass = site.facade.upstream;
            extraConfig = site.facade.extraConfig;
          };
        });
      })
    ) cfg.sites;
  };
}