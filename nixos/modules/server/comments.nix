{ config, lib, pkgs, ... }:

let
  cfg = config.sccl.comments;
in
{
  options.sccl.comments = {
    enable = lib.mkEnableOption "comments.pierdol.ing API service";
  };

  config = lib.mkIf cfg.enable {
    # secrets
    sops.secrets."comments/db-password" = {
      sopsFile = ../../../secrets/db.yaml;
    };

    sops.secrets."comments/user-id" = {
      sopsFile = ../../../secrets/apps.yaml;
    };

    sops.secrets."comments/tg-bot-token" = {
      sopsFile = ../../../secrets/apps.yaml;
    };

    sops.secrets."comments/api-secret" = {
      sopsFile = ../../../secrets/apps.yaml;
    };

    sops.templates."comments-env" = {
      content = ''
        DATABASE_URL=postgresql://comments:${config.sops.placeholder."comments/db-password"}@10.69.0.1:5432/comments
        TELEGRAM_USER_ID=${config.sops.placeholder."comments/user-id"}
        TELEGRAM_BOT_TOKEN=${config.sops.placeholder."comments/tg-bot-token"}
        BOT_SECRET=${config.sops.placeholder."comments/api-secret"}
      '';
      path = "/etc/nixos/secrets/comments-env";
      mode = "0400";
    };

    # usr
    users.users.comments = {
      isSystemUser = true;
      group = "comments";
    };
    users.groups.comments = {};

    # container
    virtualisation.oci-containers.containers.comments = {
      image = "10.69.0.17:5000/scclie/comments:main";
      autoStart = true;
      environment = {
        PORT = "3000";
      };
      environmentFiles = [ "/etc/nixos/secrets/comments-env" ];
      extraOptions = [
        "--network=host"
        "--label=com.docker.compose.project=comments"
      ];
    };

    systemd.services."docker-comments" = {
      after = lib.mkAfter [ "sops-install-secrets.service" "comments-db.service" ];
      requires = [ "comments-db.service" ];
      serviceConfig = {
        Restart = lib.mkForce "always";
        RestartSec = "5s";
      };
    };

    # db init
    systemd.services.comments-db = {
      description = "Create comments PostgreSQL database";
      after = [ "postgresql.service" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        LoadCredential = [
          "db-password:/run/secrets/comments/db-password"
        ];
      };
      script = let
        psql = config.services.postgresql.package;
        asPostgres = "${pkgs.sudo}/bin/sudo -u postgres ${psql}/bin/psql";
      in ''
        DB_PASS="$(cat $CREDENTIALS_DIRECTORY/db-password)"
        ${asPostgres} -tc "SELECT 1 FROM pg_roles WHERE rolname = 'comments'" | ${pkgs.gnugrep}/bin/grep -q 1 || \
          ${asPostgres} -c "CREATE USER comments;"
        ${asPostgres} -c "ALTER USER comments WITH PASSWORD '$DB_PASS';"
        ${asPostgres} -tc "SELECT 1 FROM pg_database WHERE datname = 'comments'" | ${pkgs.gnugrep}/bin/grep -q 1 || \
          ${asPostgres} -c "CREATE DATABASE comments OWNER comments;"
        ${asPostgres} -c "GRANT ALL PRIVILEGES ON DATABASE comments TO comments;"
      '';
    };

    # firewall
    networking.firewall.allowedTCPPorts = [ 3000 ];

    # nginx
    services.nginx.virtualHosts."comments.pierdol.ing" = {
      forceSSL = true;
      enableACME = false;
      sslCertificate = "/var/lib/acme/wildcard.pierdol.ing/fullchain.pem";
      sslCertificateKey = "/var/lib/acme/wildcard.pierdol.ing/key.pem";

      locations."/" = {
        proxyPass = "http://127.0.0.1:3000";
        proxyWebsockets = true;
      };
    };

    # dns
    services.powerdns.extraConfig = ''
      # comments.pierdol.ing A record
    '';
  };
}
