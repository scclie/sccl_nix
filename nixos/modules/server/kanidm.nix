{ config, lib, pkgs, ... }:
let
  cfg = config.sccl.kanidm;
in {
  options.sccl.kanidm = {
    enable = lib.mkEnableOption "Kanidm IdP (id.pierdol.ing) and OIDC SSO";
    domain = lib.mkOption {
      type = lib.types.str;
      default = "pierdol.ing";
      description = "Parent domain; the IdP lives at id.<domain>.";
    };
  };

  config = lib.mkIf cfg.enable {
    users.users.kanidm.extraGroups = [ "acme" ];

    networking.hosts."192.168.0.10" = [ "id.${cfg.domain}" ];

    services.kanidm.client.enable = true;
    services.kanidm.client.settings.uri = "https://id.${cfg.domain}";

    sops.secrets."kanidm/admin-password" = {
      sopsFile = ../../../secrets/apps.yaml;
      owner = "kanidm";
      group = "kanidm";
    };
    sops.secrets."kanidm/oauth2-continuwuity-secret" = {
      sopsFile = ../../../secrets/apps.yaml;
      owner = "kanidm";
      group = "kanidm";
    };


    sops.templates."continuwuity-oidc.env".content =
      "CONTINUWUITY_OAUTH__OIDC__CLIENT_SECRET=${config.sops.placeholder."kanidm/oauth2-continuwuity-secret"}\n";

    services.kanidm = {
      server.enable = true;
      package = pkgs.kanidm_1_8.withSecretProvisioning;
      server.settings = {
        bindaddress = "127.0.0.1:8443";
        origin = "https://id.${cfg.domain}";
        domain = "id.${cfg.domain}";
        tls_chain = "/var/lib/acme/wildcard.${cfg.domain}/fullchain.pem";
        tls_key = "/var/lib/acme/wildcard.${cfg.domain}/key.pem";
      };
      provision = {
        enable = true;

        acceptInvalidCerts = true;
        idmAdminPasswordFile = config.sops.secrets."kanidm/admin-password".path;
        systems.oauth2.continuwuity = {
          displayName = "Continuwuity";
          originUrl = "https://${cfg.domain}/_continuwuity/oidc/complete";
          originLanding = "https://${cfg.domain}";
          basicSecretFile = config.sops.secrets."kanidm/oauth2-continuwuity-secret".path;
        };
      };
    };

    services.nginx.virtualHosts."id.${cfg.domain}" = {
      addSSL = true;
      sslCertificate = "/var/lib/acme/wildcard.${cfg.domain}/fullchain.pem";
      sslCertificateKey = "/var/lib/acme/wildcard.${cfg.domain}/key.pem";
      locations."/" = {
        proxyPass = "https://127.0.0.1:8443";
        proxyWebsockets = true;
        extraConfig = ''
          proxy_ssl_verify off;
          proxy_buffering off;
        '';
      };
    };
  };
}
