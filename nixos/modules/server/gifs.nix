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
