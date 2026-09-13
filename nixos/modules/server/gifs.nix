{ config, lib, pkgs, ... }:
let
  cfg = config.sccl.gifs;
in {
  options.sccl.gifs = {
    enable = lib.mkEnableOption "gif.sccl.cc API backend (OCI container, deployed by Forgejo CI)";
  };

  config = lib.mkIf cfg.enable {
    sops.secrets."gif-sccl/db-password" = {
      sopsFile = ../../../secrets/db.yaml;
    };
    sops.secrets."gif/discord-client-id" = {
      sopsFile = ../../../secrets/apps.yaml;
    };
    sops.secrets."gif/discord-client-secret" = {
      sopsFile = ../../../secrets/apps.yaml;
    };
    sops.secrets."gif/turnstile-site-key" = {
      sopsFile = ../../../secrets/apps.yaml;
    };
    sops.secrets."gif/turnstile-secret-key" = {
      sopsFile = ../../../secrets/apps.yaml;
    };

    sops.templates."gif-env" = {
      content = ''
        DATABASE_URL=postgresql://gif:${config.sops.placeholder."gif-sccl/db-password"}@10.69.0.1:5432/gif
        DATA_DIR=/var/gifs
        DISCORD_CLIENT_ID=${config.sops.placeholder."gif/discord-client-id"}
        DISCORD_CLIENT_SECRET=${config.sops.placeholder."gif/discord-client-secret"}
        DISCORD_REDIRECT_URI=https://gif.sccl.cc/api/auth/callback
        TURNSTILE_SITE_KEY=${config.sops.placeholder."gif/turnstile-site-key"}
        TURNSTILE_SECRET_KEY=${config.sops.placeholder."gif/turnstile-secret-key"}
        PORT=8083
      '';
      path = "/etc/nixos/secrets/gif-env";
      mode = "0400";
    };

    virtualisation.oci-containers = {
      backend = "docker";
      containers.gifs = {
        image = "10.69.0.17:5000/scclie/gif:main";
        autoStart = true;
        pull = "always";
        volumes = [ "/tank/gifs:/var/gifs" ];
        extraOptions = [ "--network=host" ];
        environmentFiles = [ "/etc/nixos/secrets/gif-env" ];
      };
    };

    systemd.services."docker-gifs" = {
      after = lib.mkAfter [ "sops-install-secrets.service" ];
      serviceConfig = {
        Restart = lib.mkForce "always";
        RestartSec = "5s";
      };
    };

    virtualisation.docker.autoPrune = {
      enable = true;
    };

    systemd.services.gifs-db = {
      description = "Create gif.sccl PostgreSQL database";
      after = [ "postgresql.service" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        LoadCredential = [
          "db-password:/run/secrets/gif-sccl/db-password"
        ];
      };
      script = let
        psql = config.services.postgresql.package;
        asPostgres = "${pkgs.sudo}/bin/sudo -u postgres ${psql}/bin/psql";
      in ''
        DB_PASS="$(cat $CREDENTIALS_DIRECTORY/db-password)"
        ${asPostgres} -tc "SELECT 1 FROM pg_roles WHERE rolname = 'gif'" | ${pkgs.gnugrep}/bin/grep -q 1 || \
          ${asPostgres} -c "CREATE USER gif WITH PASSWORD '$DB_PASS';"
        ${asPostgres} -tc "SELECT 1 FROM pg_database WHERE datname = 'gif'" | ${pkgs.gnugrep}/bin/grep -q 1 || \
          ${asPostgres} -c "CREATE DATABASE gif OWNER gif;"
        ${asPostgres} -c "GRANT ALL PRIVILEGES ON DATABASE gif TO gif;"
      '';
    };
  };
}
