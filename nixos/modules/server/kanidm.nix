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
    sops.secrets."kanidm/oauth2-grafana-secret" = {
      sopsFile = ../../../secrets/apps.yaml;
      owner = "kanidm";
      group = "kanidm";
    };
    sops.secrets."kanidm/oauth2-oauth2proxy-secret" = {
      sopsFile = ../../../secrets/apps.yaml;
      owner = "kanidm";
      group = "kanidm";
    };
    sops.secrets."kanidm/oauth2-gif-secret" = {
      sopsFile = ../../../secrets/apps.yaml;
      owner = "kanidm";
      group = "kanidm";
    };
    sops.secrets."oauth2-proxy/cookie-secret" = {
      sopsFile = ../../../secrets/apps.yaml;
      owner = "oauth2-proxy";
      group = "oauth2-proxy";
    };

    # oauth2-proxy needs to read its own copy of the client secret
    sops.templates."oauth2proxy-client-secret" = {
      content = "${config.sops.placeholder."kanidm/oauth2-oauth2proxy-secret"}";
      owner = "oauth2-proxy";
      group = "oauth2-proxy";
      mode = "0400";
    };

    # rendered on the host; grafana reads the client secret from its env
    sops.templates."grafana-oidc.env".content =
      "GF_AUTH_GENERIC_OAUTH_CLIENT_SECRET=${config.sops.placeholder."kanidm/oauth2-grafana-secret"}\n";


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
        systems.oauth2.grafana = {
          displayName = "Grafana";
          originUrl = "https://grafana.sccl.cc/login/generic_oauth";
          originLanding = "https://grafana.sccl.cc";
          basicSecretFile = config.sops.secrets."kanidm/oauth2-grafana-secret".path;
          scopeMaps."services" = [ "openid" "profile" "email" "groups" ];
          preferShortUsername = true;
          # grafana generic oauth does not send a PKCE challenge
          allowInsecureClientDisablePkce = true;
        };
        # overwriteMembers off so members added via CLI are not wiped
        groups.services = { overwriteMembers = false; };
        groups.grafana_admins = { overwriteMembers = false; };
        groups.gif_admins = { overwriteMembers = false; };
        systems.oauth2.oauth2proxy = {
          displayName = "Monitoring SSO";
          originUrl = [
            "https://prometheus.sccl.cc/oauth2/callback"
            "https://loki.sccl.cc/oauth2/callback"
            "https://alertmanager.sccl.cc/oauth2/callback"
          ];
          originLanding = "https://prometheus.sccl.cc";
          basicSecretFile = config.sops.secrets."kanidm/oauth2-oauth2proxy-secret".path;
          scopeMaps."services" = [ "openid" "profile" "email" "groups" ];
          allowInsecureClientDisablePkce = true;
        };
        systems.oauth2.gif = {
          displayName = "gif.sccl.cc";
          originUrl = "https://gif.sccl.cc/api/auth/kanidm/callback";
          originLanding = "https://gif.sccl.cc";
          basicSecretFile = config.sops.secrets."kanidm/oauth2-gif-secret".path;
          preferShortUsername = true;
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

    # kanidm-provision cannot target the builtin idm_all_persons in scopeMaps,
    # so set the gif client's scope map to it via the CLI: any kanidm person
    # may sign in to gif.sccl.cc (admin role still needs the gif_admins group)
    systemd.services.kanidm-oauth-scopes = {
      description = "kanidm: allow idm_all_persons to sign in to gif.sccl.cc";
      after = [ "kanidm.service" ];
      requires = [ "kanidm.service" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      script = ''
        export KANIDM_URL=https://id.${cfg.domain}
        export KANIDM_PASSWORD="$(cat ${config.sops.secrets."kanidm/admin-password".path})"
        KANIDM=${lib.getExe' pkgs.kanidm_1_8.withSecretProvisioning "kanidm"}
        "$KANIDM" login --name idm_admin
        "$KANIDM" system oauth2 update-scope-map gif idm_all_persons openid profile email groups
      '';
    };
  };
}
