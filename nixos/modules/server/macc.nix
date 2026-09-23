{ config, lib, pkgs, ... }:

let
  cfg = config.sccl.macc;
  domain = config.sccl.matrix.domain;
in
{
  options.sccl.macc = {
    enable = lib.mkEnableOption "macc self-service matrix account portal (macc.pierdol.ing)";
  };

  config = lib.mkIf cfg.enable {
    # bot token
    sops.secrets."macc/matrix-admin-token" = {
      sopsFile = ../../../secrets/apps.yaml;
    };

    # oauth2-proxy instance is a manual unit
    sops.secrets."oauth2-proxy-macc/cookie-secret" = {
      sopsFile = ../../../secrets/apps.yaml;
      owner = "macc";
      group = "macc";
      mode = "0400";
    };

    # oauth2-proxy reads kanidm client secret
    sops.templates."macc-oauth2-client-secret" = {
      content = "${config.sops.placeholder."kanidm/oauth2-macc-secret"}";
      owner = "macc";
      group = "macc";
      mode = "0400";
    };

    # container env
    sops.templates."macc-env" = {
      content = ''
        PORT=8787
        HS=http://10.69.0.19:6167
        HS_DOMAIN=${domain}
        WEB_URL=https://chat.${domain}
        ADMIN_TOKEN=${config.sops.placeholder."macc/matrix-admin-token"}
        ADMIN_USER=@maccbot:${domain}
        ADMIN_ROOM=#admins:${domain}
        STATE_DIR=/var/lib/macc
      '';
      path = "/etc/nixos/secrets/macc-env";
      mode = "0400";
    };

    # usr
    users.users.macc = {
      isSystemUser = true;
      group = "macc";
    };
    users.groups.macc = {};

    system.activationScripts.macc-dirs = lib.mkAfter ''
      mkdir -p /tank/macc
      chown 20900:20900 /tank/macc
      chmod 700 /tank/macc
    '';

    # container
    virtualisation.oci-containers.containers.macc = {
      image = "10.69.0.17:5000/scclie/macc:main";
      autoStart = true;
      environmentFiles = [ "/etc/nixos/secrets/macc-env" ];
      extraOptions = [
        "--network=host"
        "--label=com.docker.compose.project=macc"
        "--volume"
        "/tank/macc:/var/lib/macc"
      ];
    };

    systemd.services."docker-macc" = {
      after = lib.mkAfter [ "sops-install-secrets.service" ];
      serviceConfig = {
        Restart = lib.mkForce "always";
        RestartSec = "5s";
        ExecStartPre = [ "${pkgs.docker}/bin/docker pull 10.69.0.17:5000/scclie/macc:main" ];
      };
    };

    # another one oauth2-proxy
    systemd.services.oauth2-proxy-macc = {
      description = "oauth2-proxy for macc (macc.pierdol.ing)";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      wantedBy = [ "multi-user.target" ];
      script = ''
        exec ${pkgs.oauth2-proxy}/bin/oauth2-proxy \
          --provider=oidc \
          --oidc-issuer-url=https://id.${domain}/oauth2/openid/macc \
          --client-id=macc \
          --client-secret-file=${config.sops.templates."macc-oauth2-client-secret".path} \
          --email-domain=* \
          --http-address=127.0.0.1:4181 \
          --upstream=static://202 \
          --set-xauthrequest=true \
          --reverse-proxy \
          --trusted-proxy-ip=127.0.0.1 \
          --cookie-domain=.${domain} \
          --cookie-secret-file=${config.sops.secrets."oauth2-proxy-macc/cookie-secret".path} \
          --cookie-secure=true \
          --whitelist-domain=.${domain}
      '';
      serviceConfig = {
        User = "macc";
        Group = "macc";
        Restart = "on-failure";
        RestartSec = 5;
        NoNewPrivileges = true;
        ProtectSystem = "strict";
        ProtectHome = true;
      };
    };

    # nginx
    services.nginx.virtualHosts."macc.${domain}" = {
      forceSSL = true;
      enableACME = false;
      sslCertificate = "/var/lib/acme/wildcard.${domain}/fullchain.pem";
      sslCertificateKey = "/var/lib/acme/wildcard.${domain}/key.pem";

      locations = {
        "= /healthz" = {
          proxyPass = "http://127.0.0.1:8787";
        };
        "/" = {
          proxyPass = "http://127.0.0.1:8787";
          extraConfig = ''
            auth_request /oauth2/auth;
            error_page 401 = /oauth2/sign_in;
            auth_request_set $ls_username $upstream_http_x_auth_request_preferred_username;
            auth_request_set $ls_groups $upstream_http_x_auth_request_groups;
            proxy_set_header X-Auth-Request-Preferred-Username $ls_username;
            proxy_set_header X-Auth-Request-Groups $ls_groups;
            proxy_set_header X-Real-IP $remote_addr;
          '';
        };
        "/oauth2/" = {
          proxyPass = "http://127.0.0.1:4181";
          extraConfig = ''
            proxy_set_header X-Real-IP $remote_addr;
          '';
        };
        "= /oauth2/auth" = {
          proxyPass = "http://127.0.0.1:4181";
          extraConfig = ''
            internal;
            proxy_pass_request_body off;
            proxy_set_header X-Original-URI $request_uri;
            proxy_set_header Content-Length "";
            proxy_set_header X-Real-IP $remote_addr;
          '';
        };
      };
    };
  };
}
