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
      restartUnits = [ "container@vaultwarden-ct.service" ];
    };
    sops.secrets."vaultwarden/db-password" = {
      sopsFile = ../../../secrets/db.yaml;
      restartUnits = [ "container@vaultwarden-ct.service" ];
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
        "/run/secrets/vaultwarden/admin-token" = {
          hostPath = config.sops.secrets."vaultwarden/admin-token".path;
          isReadOnly = true;
        };
        "/run/secrets/vaultwarden/db-password" = {
          hostPath = config.sops.secrets."vaultwarden/db-password".path;
          isReadOnly = true;
        };
      };

      config = { config, lib, pkgs, ... }: {
        system.stateVersion = "26.05";

        environment.systemPackages = [
          (pkgs.vaultwarden.override { dbBackend = "postgresql"; })
        ];

        systemd.services.vaultwarden = {
          description = "Vaultwarden server";
          after = [ "network.target" ];
          wantedBy = [ "multi-user.target" ];
          serviceConfig = {

            LoadCredential = [
              "admin-token:/run/secrets/vaultwarden/admin-token"
              "db-password:/run/secrets/vaultwarden/db-password"
            ];
            ExecStart = lib.mkForce (pkgs.writeShellScript "vaultwarden-wrapped" ''
              export ADMIN_TOKEN="$(cat $CREDENTIALS_DIRECTORY/admin-token)"
              export DATABASE_URL="postgresql://vaultwarden:$(cat $CREDENTIALS_DIRECTORY/db-password)@10.69.0.1:5432/vaultwarden"
              exec ${pkgs.vaultwarden.override { dbBackend = "postgresql"; }}/bin/vaultwarden
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
            SIGNUPS_ALLOWED = "false";
            ROCKET_ADDRESS = "0.0.0.0";
            WEB_VAULT_FOLDER = "${pkgs.vaultwarden.webvault}/share/vaultwarden/vault";
          };
        };


        systemd.tmpfiles.rules = [
          "Z /var/lib/vaultwarden 0700 vaultwarden vaultwarden -"
        ];

        users.users.vaultwarden = {
          isSystemUser = true;
          group = "vaultwarden";
          uid = 997;
        };
        users.groups.vaultwarden = { gid = 995; };

        networking.firewall.allowedTCPPorts = [ cfg.port ];
      };
    };

    # nginx proxy
    sccl.proxy.sites.pass = {
      upstream = "http://${containerIp}:${toString cfg.port}";
      extraConfig = ''
        proxy_read_timeout 300s;
        proxy_send_timeout 300s;
        client_max_body_size 525M;
      '';
    };

    # websocket support
    sccl.proxy.sites."pass-api" = {
      upstream = "http://${containerIp}:${toString cfg.port}/notifications/hub";
      extraConfig = ''
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
      '';
    };

    # vw pgsql db
    systemd.services.vaultwarden-db = {
      description = "Create Vaultwarden PostgreSQL database";
      after = [ "postgresql.service" ];
      requires = [ "postgresql.service" ];
      wantedBy = [ "multi-user.target" ];
      startLimitIntervalSec = 0;
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        Restart = "on-failure";
        RestartSec = "5s";
        LoadCredential = [
          "db-password:/run/secrets/vaultwarden/db-password"
        ];
      };
      script = let
        psql = config.services.postgresql.package;
        asPostgres = "${pkgs.sudo}/bin/sudo -u postgres ${psql}/bin/psql";
      in ''
        DB_PASS="$(cat $CREDENTIALS_DIRECTORY/db-password)"
        ${asPostgres} -tc "SELECT 1 FROM pg_roles WHERE rolname = 'vaultwarden'" | ${pkgs.gnugrep}/bin/grep -q 1 || \
          ${asPostgres} -c "CREATE USER vaultwarden WITH PASSWORD '$DB_PASS';"
        ${asPostgres} -tc "SELECT 1 FROM pg_database WHERE datname = 'vaultwarden'" | ${pkgs.gnugrep}/bin/grep -q 1 || \
          ${asPostgres} -c "CREATE DATABASE vaultwarden OWNER vaultwarden;"
        ${asPostgres} -c "GRANT ALL PRIVILEGES ON DATABASE vaultwarden TO vaultwarden;"
      '';
    };
  };
}
