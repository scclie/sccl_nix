{ config, lib, pkgs, ... }:
let
  cfg = config.sccl.vaultwarden;
  containerIp = "10.69.0.16";
in {
  options.sccl.vaultwarden = {
    enable = lib.mkEnableOption "Vaultwarden password manager";
    port = lib.mkOption {
      type = lib.types.port;
      default = 8000;
      description = "Vaultwarden HTTP port";
    };
    domain = lib.mkOption {
      type = lib.types.str;
      default = "https://pass.sccl.cc";
      description = "Vaultwarden domain for notifications";
    };
  };

  config = lib.mkIf cfg.enable {
    # Declare secrets at host level
    sops.secrets."vaultwarden/admin-token" = {
      sopsFile = ../../../secrets/apps.yaml;
    };
    sops.secrets."vaultwarden/db-password" = {
      sopsFile = ../../../secrets/db.yaml;
    };

    containers.vaultwarden-ct = {
      autoStart = true;
      ephemeral = false;
      privateNetwork = true;
      hostAddress = "10.69.0.1";
      localAddress = containerIp;
      hostBridge = "br-svc";

      bindMounts = {
        "/var/lib/vaultwarden" = {
          hostPath = "/tank/vw";
          isReadOnly = false;
        };
        "/run/secrets" = {
          hostPath = "/run/secrets";
          isReadOnly = true;
        };
      };

      config = { config, lib, pkgs, ... }: {
        system.stateVersion = "26.05";

        environment.systemPackages = [ pkgs.vaultwarden ];

        systemd.services.vaultwarden = {
          description = "Vaultwarden server";
          after = [ "network.target" ];
          wantedBy = [ "multi-user.target" ];
          serviceConfig = {
            ExecStart = lib.mkForce (pkgs.writeShellScript "vaultwarden-wrapped" ''
              export ADMIN_TOKEN="$(cat /run/secrets/vaultwarden/admin-token)"
              export DATABASE_URL="postgresql://vaultwarden:$(cat /run/secrets/vaultwarden/db-password)@10.69.0.1:5432/vaultwarden"
              exec ${pkgs.vaultwarden}/bin/vaultwarden
            '');
            User = "vaultwarden";
            Group = "vaultwarden";
            Restart = "always";
            RestartSec = 5;
          };
          environment = {
            DATA_FOLDER = "/var/lib/vaultwarden";
            DOMAIN = cfg.domain;
            WEBSOCKET_ENABLED = "true";
          };
        };

        users.users.vaultwarden = {
          isSystemUser = true;
          group = "vaultwarden";
        };
        users.groups.vaultwarden = {};
      };
    };

    # Expose via nginx proxy
    sccl.proxy.sites.pass = {
      upstream = "http://${containerIp}:${toString cfg.port}";
      extraConfig = ''
        proxy_read_timeout 300s;
        proxy_send_timeout 300s;
        client_max_body_size 525M;
      '';
    };

    # WebSocket support
    sccl.proxy.sites."pass-api" = {
      upstream = "http://${containerIp}:${toString cfg.port}/notifications/hub";
      extraConfig = ''
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
      '';
    };

    # PostgreSQL database for Vaultwarden
    systemd.services.vaultwarden-db = {
      description = "Create Vaultwarden PostgreSQL database";
      after = [ "postgresql.service" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        LoadCredential = [
          "db-password:/run/secrets/vaultwarden/db-password"
        ];
      };
      script = let
        psql = config.services.postgresql.package;
      in ''
        DB_PASS="$(cat %d/db-password)"
        ${psql}/bin/psql -tc "SELECT 1 FROM pg_roles WHERE rolname = 'vaultwarden'" | ${pkgs.gnugrep}/bin/grep -q 1 || \
          ${psql}/bin/psql -c "CREATE USER vaultwarden WITH PASSWORD '$DB_PASS';"
        ${psql}/bin/psql -tc "SELECT 1 FROM pg_database WHERE datname = 'vaultwarden'" | ${pkgs.gnugrep}/bin/grep -q 1 || \
          ${psql}/bin/psql -c "CREATE DATABASE vaultwarden OWNER vaultwarden;"
        ${psql}/bin/psql -c "GRANT ALL PRIVILEGES ON DATABASE vaultwarden TO vaultwarden;"
      '';
    };
  };
}
