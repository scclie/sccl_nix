{ config, lib, pkgs, ... }:
let
  cfg = config.sccl.proxy;
  serverCfg = config.sccl.server;
in {
  options.sccl.proxy = {
    enable = lib.mkEnableOption "nginx reverse proxy with ACME wildcard";
    sites = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule {
        options = {
          upstream = lib.mkOption {
            type = lib.types.str;
            description = "Upstream address (e.g. http://127.0.0.1:8080 or http://10.69.0.2:80)";
          };
          extraConfig = lib.mkOption {
            type = lib.types.str;
            default = "";
            description = "Extra nginx location config";
          };
        };
      });
      default = {};
      description = "Virtual host sites to proxy";
    };
  };

  config = lib.mkIf cfg.enable {
    services.nginx = {
      enable = true;
      recommendedProxySettings = true;
      recommendedTlsSettings = true;
      recommendedOptimisation = true;
      recommendedGzipSettings = true;
      recommendedBrotliSettings = true;

      appendHttpConfig = ''
        limit_req_zone $binary_remote_addr zone=general:10m rate=10r/s;
        limit_req_zone $binary_remote_addr zone=api:10m rate=30r/s;
        server_names_hash_bucket_size 128;

        ssl_protocols TLSv1.2 TLSv1.3;
        ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384;
        ssl_prefer_server_ciphers off;
        ssl_session_timeout 1d;
        ssl_session_cache shared:SSL:10m;
        ssl_stapling on;
        ssl_stapling_verify on;
      '';
    };

    # ACME wildcard certificate
    security.acme = {
      acceptTerms = true;
      defaults.email = serverCfg.acmeEmail;
      certs."wildcard.${serverCfg.domain}" = {
        domain = "*.${serverCfg.domain}";
        dnsProvider = "cloudflare";
        environmentFile = "/etc/nixos/secrets/cloudflare-api-token.env";
        extraDomainNames = [ serverCfg.domain ];
      };
    };

    # TODO: Add 'cloudflare-api-token' key to secrets/personal.yaml and uncomment sops declaration
    # sops.secrets."cloudflare-api-token" = {
    #   path = "/etc/nixos/secrets/cloudflare-api-token.env";
    #   owner = "acme";
    #   group = "acme";
    #   mode = "0400";
    # };

    # All virtual hosts: default catch-all + site proxies
    services.nginx.virtualHosts = lib.mkMerge [
      {
        "_${serverCfg.domain}" = {
          default = true;
          addSSL = true;
          sslCertificate = "/var/lib/acme/wildcard.${serverCfg.domain}/fullchain.pem";
          sslCertificateKey = "/var/lib/acme/wildcard.${serverCfg.domain}/key.pem";
          locations."/" = {
            return = "404";
          };
        };
      }
      (lib.mapAttrs' (name: site:
        lib.nameValuePair "${name}.${serverCfg.domain}" {
          addSSL = true;
          sslCertificate = "/var/lib/acme/wildcard.${serverCfg.domain}/fullchain.pem";
          sslCertificateKey = "/var/lib/acme/wildcard.${serverCfg.domain}/key.pem";
          locations."/" = {
            proxyPass = site.upstream;
            extraConfig = site.extraConfig + ''
              limit_req zone=general burst=20 nodelay;
            '';
          };
        }
      ) cfg.sites)
    ];
  };
}
