{ config, lib, pkgs, ... }:
let
  cfg = config.sccl.forgejo;
  serverCfg = config.sccl.server;
in {
  options.sccl.forgejo = {
    enable = lib.mkEnableOption "Forgejo git forge + runner + registry";
  };

  config = lib.mkIf cfg.enable {
    # Declare secrets at host level (decrypted to /run/secrets/)
    sops.secrets."forgejo/db-password" = {
      sopsFile = ../../../secrets/db.yaml;
    };
    sops.secrets."forgejo/internal-token" = {
      sopsFile = ../../../secrets/apps.yaml;
    };
    sops.secrets."forgejo/jwt-secret" = {
      sopsFile = ../../../secrets/apps.yaml;
    };

    # Git container
    containers.git-ct = {
      autoStart = true;
      ephemeral = true;
      privateNetwork = true;
      hostAddress = "10.69.0.1";
      localAddress = "10.69.0.10";
      hostBridge = "br-svc";

      bindMounts = {
        "/var/lib/forgejo" = {
          hostPath = "/tank/forgejo";
          isReadOnly = false;
        };
        # Bind-mount host's decrypted secrets (read-only)
        "/run/secrets" = {
          hostPath = "/run/secrets";
          isReadOnly = true;
        };
      };

      config = { config, lib, pkgs, ... }: {
        system.stateVersion = "26.05";

        services.forgejo = {
          enable = true;
          package = pkgs.forgejo;
          stateDir = "/var/lib/forgejo";
          settings = {
            server = {
              DOMAIN = "git.${serverCfg.domain}";
              ROOT_URL = "https://git.${serverCfg.domain}/";
              HTTP_PORT = 3000;
              LFS_START_SERVER = true;
              SSH_DOMAIN = "git.${serverCfg.domain}";
              SSH_PORT = 22;
              DISABLE_SSH = false;
            };
            database = lib.mkForce {
              DB_TYPE = "postgres";
              HOST = "10.69.0.13:5432";
              NAME = "forgejo";
              USER = "forgejo";
            };
            service = {
              DISABLE_REGISTRATION = false;
              REQUIRE_SIGNIN_VIEW = true;
            };
            actions = {
              ENABLED = true;
            };
            security = {
              INSTALL_LOCK = true;
            };
          };
        };

        # Load credentials via systemd (article pattern)
        # Bind-mount provides /run/secrets/*, LoadCredential copies to /run/credentials/
        systemd.services.forgejo = {
          serviceConfig = {
            LoadCredential = [
              "db-password:/run/secrets/forgejo/db-password"
              "internal-token:/run/secrets/forgejo/internal-token"
              "jwt-secret:/run/secrets/forgejo/jwt-secret"
            ];
            ExecStart = lib.mkForce (pkgs.writeShellScript "forgejo-wrapped" ''
              export FORGEJO__database__PASSWD="$(cat %d/db-password)"
              export FORGEJO__security__INTERNAL_TOKEN="$(cat %d/internal-token)"
              export FORGEJO__security__SECRET_KEY="$(cat %d/jwt-secret)"
              exec ${config.services.forgejo.package}/bin/forgejo web --config /var/lib/forgejo/conf/app.ini
            '');
          };
        };

        networking.firewall = {
          allowedTCPPorts = [ 3000 22 ];
        };
      };
    };

    # OCI registry container
    containers.registry-ct = {
      autoStart = true;
      ephemeral = true;
      privateNetwork = true;
      hostAddress = "10.69.0.1";
      localAddress = "10.69.0.17";
      hostBridge = "br-svc";

      bindMounts = {
        "/var/lib/registry" = {
          hostPath = "/tank/apps/registry";
          isReadOnly = false;
        };
      };

      config = { config, pkgs, ... }: {
        system.stateVersion = "26.05";

        services.dockerRegistry = {
          enable = true;
          listenAddress = "0.0.0.0";
          port = 5000;
          storagePath = "/var/lib/registry";
        };

        networking.firewall = {
          allowedTCPPorts = [ 5000 ];
        };
      };
    };

    # Create PostgreSQL database for Forgejo
    systemd.services.forgejo-db = {
      description = "Create Forgejo PostgreSQL database";
      after = [ "postgresql.service" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        LoadCredential = [
          "db-password:/run/secrets/forgejo/db-password"
        ];
      };
      script = let
        psql = config.services.postgresql.package;
      in ''
        DB_PASS="$(cat %d/db-password)"
        ${psql}/bin/psql -tc "SELECT 1 FROM pg_roles WHERE rolname = 'forgejo'" | ${pkgs.gnugrep}/bin/grep -q 1 || \
          ${psql}/bin/psql -c "CREATE USER forgejo WITH PASSWORD '$DB_PASS';"
        ${psql}/bin/psql -tc "SELECT 1 FROM pg_database WHERE datname = 'forgejo'" | ${pkgs.gnugrep}/bin/grep -q 1 || \
          ${psql}/bin/psql -c "CREATE DATABASE forgejo OWNER forgejo;"
        ${psql}/bin/psql -c "GRANT ALL PRIVILEGES ON DATABASE forgejo TO forgejo;"
      '';
    };
  };
}
