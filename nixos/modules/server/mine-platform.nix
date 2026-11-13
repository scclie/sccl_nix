{ config, lib, pkgs, ... }:
let
  cfg = config.sccl.minePlatform;
  secretNames = map (name: "mine-platform/${name}") [
    "db-password" "discord-client-id" "discord-client-secret" "session-signing-key"
  ];
  secrets = map (name: config.sops.secrets.${name} or null) secretNames;
  configuredSecrets = builtins.all (s: s != null && s.key != "" && s.mode == "0400"
    && (s.owner == null || s.owner == "root") && s.uid == 0) secrets;
  validId = id: builtins.match "[1-9][0-9]{0,19}" id != null
    && (builtins.stringLength id < 20 || builtins.lessThan id "18446744073709551616");
  allIds = cfg.adminDiscordIds ++ cfg.moderatorDiscordIds;
  environmentFile = "/etc/nixos/secrets/mine-platform-env";
  image = "10.69.0.17:5000/scclie/mine-platform:main";
  hardening = {
    # container runs as 20903:20903.
    NoNewPrivileges = true;
    PrivateTmp = true;
    ProtectSystem = "strict";
    ProtectHome = true;
    ProtectKernelTunables = true;
    ProtectControlGroups = true;
    RestrictAddressFamilies = [ "AF_UNIX" "AF_INET" "AF_INET6" ];
    CapabilityBoundingSet = "";
    UMask = "0077";
    LimitCORE = 0;
    PrivateDevices = true;
    TimeoutStartSec = "15min";
  };
in {
  options.sccl.minePlatform = {
    enable = lib.mkEnableOption "mine.pierdol.ing platform API and static facade";
    sitePath = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = "Deployed static release root; the sites facade requires /tank/sites/mine/public.";
    };
    adminDiscordIds = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "Explicit administrator Discord snowflakes (at least one required).";
    };
    moderatorDiscordIds = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "Moderator Discord snowflakes; must not overlap administrators.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      { assertion = config.sccl.server.enable && config.virtualisation.oci-containers.backend == "docker";
        message = "sccl.minePlatform requires the server security policy and Docker OCI backend."; }
      { assertion = cfg.sitePath != "";
        message = "sccl.minePlatform.enable requires a nonempty sitePath."; }
      { assertion = cfg.sitePath == "/tank/sites/mine/public";
        message = "sccl.minePlatform.sitePath must be /tank/sites/mine/public (sites facade naming convention)."; }
      { assertion = cfg.adminDiscordIds != [];
        message = "sccl.minePlatform.enable requires nonempty adminDiscordIds; configure an administrator explicitly."; }
      { assertion = builtins.all validId allIds && lib.length (lib.unique allIds) == lib.length allIds;
        message = "sccl.minePlatform Discord IDs must be canonical unsigned 64-bit decimal strings, unique and non-overlapping."; }
      { assertion = configuredSecrets && lib.length (lib.unique (map (s: "${toString s.sopsFile}:${s.key}") secrets)) == 4
          && lib.length (lib.unique (map (s: s.path) secrets)) == 4;
        message = "sccl.minePlatform requires four separate configured root-only 0400 sops secrets: db-password, discord-client-id, discord-client-secret, session-signing-key."; }
      { assertion = config.services.postgresql.enable;
        message = "sccl.minePlatform requires services.postgresql.enable."; }
      { assertion = config.services.postgresql.enableTCPIP && config.services.postgresql.settings.port == 5432;
        message = "sccl.minePlatform requires PostgreSQL listening on local TCP port 5432 for its DATABASE_URL."; }
      { assertion = config.sccl.proxy.enable;
        message = "sccl.minePlatform requires sccl.proxy.enable for hardened nginx, TLS and ACME."; }
    ];

    sops.secrets."mine-platform/db-password" = {
      sopsFile = ../../../secrets/db.yaml;
      mode = "0400";
      owner = "root";
    };
    sops.secrets."mine-platform/discord-client-id" = {
      sopsFile = ../../../secrets/apps.yaml;
      mode = "0400";
      owner = "root";
    };
    sops.secrets."mine-platform/discord-client-secret" = {
      sopsFile = ../../../secrets/apps.yaml;
      mode = "0400";
      owner = "root";
    };
    sops.secrets."mine-platform/session-signing-key" = {
      sopsFile = ../../../secrets/apps.yaml;
      mode = "0400";
      owner = "root";
    };

    sops.templates."mine-platform-env" = {
      path = environmentFile;
      mode = "0400";
      owner = "root";
      content = ''
        DATABASE_URL=postgresql://mine_platform:${config.sops.placeholder."mine-platform/db-password"}@10.69.0.1:5432/mine_platform
        HTTP_LISTEN_ADDRESS=0.0.0.0:8088
        PUBLIC_ORIGIN=https://mine.pierdol.ing
        DISCORD_CLIENT_ID=${config.sops.placeholder."mine-platform/discord-client-id"}
        DISCORD_CLIENT_SECRET=${config.sops.placeholder."mine-platform/discord-client-secret"}
        DISCORD_REDIRECT_URI=https://mine.pierdol.ing/api/v1/auth/discord/callback
        SESSION_SIGNING_KEY=${config.sops.placeholder."mine-platform/session-signing-key"}
        ADMIN_DISCORD_IDS=${lib.concatStringsSep "," cfg.adminDiscordIds}
        MODERATOR_DISCORD_IDS=${lib.concatStringsSep "," cfg.moderatorDiscordIds}
      '';
    };

    services.postgresql.authentication = lib.mkBefore ''
      local all mine_platform reject
      host mine_platform mine_platform 172.30.13.2/32 scram-sha-256
      host mine_platform mine_platform 172.30.13.3/32 scram-sha-256
      host mine_platform all all reject
      host all mine_platform all reject
    '';

    systemd.services.mine-platform-db = {
      description = "Provision mine platform PostgreSQL role and database";
      requires = [ "postgresql.service" ];
      after = [ "postgresql.service" ];
      before = [ "mine-platform-migrate.service" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        User = "postgres";
        Group = "postgres";
        LoadCredential = [ "db-password:${config.sops.secrets."mine-platform/db-password".path}" ];
        UMask = "0077";
        LimitCORE = 0;
        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        ProtectKernelTunables = true;
        ProtectControlGroups = true;
        RestrictAddressFamilies = [ "AF_UNIX" ];
        CapabilityBoundingSet = "";
      };
      script = ''
        set -euo pipefail
        MINE_DB_PASSWORD="$(cat "$CREDENTIALS_DIRECTORY/db-password")"
        case "$MINE_DB_PASSWORD" in
          ""|*[!a-zA-Z0-9_-]*) echo "mine-platform: database password must be nonempty URL-safe single-line text" >&2; exit 1 ;;
        esac
        export MINE_DB_PASSWORD
        ${config.services.postgresql.package}/bin/psql -X --dbname=postgres --set=ON_ERROR_STOP=1 <<'SQL'
        SET log_statement = 'none';
        SET log_min_error_statement = 'panic';
        SET password_encryption = 'scram-sha-256';
        \getenv db_password MINE_DB_PASSWORD
        SELECT 'CREATE ROLE mine_platform LOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION'
        WHERE NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'mine_platform')
        \gexec
        SELECT format('ALTER ROLE mine_platform LOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION PASSWORD %L', :'db_password')
        \gexec
        \unset db_password
        SELECT 'CREATE DATABASE mine_platform OWNER mine_platform'
        WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'mine_platform')
        \gexec
        DO $$ BEGIN
          IF EXISTS (SELECT FROM pg_database WHERE datname = 'mine_platform'
                     AND datdba <> (SELECT oid FROM pg_roles WHERE rolname = 'mine_platform')) THEN
            RAISE EXCEPTION 'mine_platform database has an unexpected owner; refusing to take ownership';
          END IF;
        END $$;
        REVOKE ALL ON DATABASE mine_platform FROM PUBLIC;
        SQL
        unset MINE_DB_PASSWORD
      '';
    };

    systemd.services.mine-platform-migrate = {
      description = "Apply mine platform database migrations";
      requires = [ "mine-platform-db.service" "docker.service" "sccl-network-mine-platform.service" ];
      after = [ "mine-platform-db.service" "docker.service" "sccl-network-mine-platform.service" ];
      before = [ "docker-mine-platform.service" ];
      environment.DOCKER_HOST = "unix:///run/docker.sock";
      environment.DOCKER_CONFIG = "/var/empty";
      serviceConfig = hardening // {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = lib.concatStringsSep " " [
          "${pkgs.docker}/bin/docker run --rm --name=mine-platform-migrate"
          "--pull=never --user=20903:20903 --network=sccl-mine-platform --ip=172.30.13.3"
          "--env-file=${environmentFile}"
          "--env=SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt"
          "--volume=${config.security.pki.caBundle}:/etc/ssl/certs/ca-certificates.crt:ro"
          "--cap-drop=ALL --security-opt=no-new-privileges:true --read-only"
          "--pids-limit=256 --memory=768m --cpus=2 --tmpfs=/tmp:rw,nosuid,nodev,noexec,size=64m"
          "${image} --migrate-only"
        ];
        ExecStopPost = "-${pkgs.docker}/bin/docker rm -f mine-platform-migrate";
      };
    };

    virtualisation.oci-containers.containers.mine-platform = {
      inherit image;
      autoStart = true;
      pull = "never";
      user = "20903:20903";
      ports = [ "127.0.0.1:8088:8088" ];
      environmentFiles = [ environmentFile ];
    };

    systemd.services.docker-mine-platform = {
      requires = [ "mine-platform-migrate.service" ];
      after = [ "mine-platform-migrate.service" ];
      serviceConfig = {
        Restart = lib.mkForce "always";
        RestartSec = "5s";
      };
    };

    sccl.sites = {
      enable = true;
      sites.mine = {
        domain = "mine.pierdol.ing";
        assetCacheControl = "no-cache"; # css/js and module imports use stable url-s.
        facade = {
          upstream = "http://127.0.0.1:8088";
          apiPrefix = "/api";
        };
      };
    };
    services.nginx.virtualHosts.mine = {
      sslCertificate = lib.mkForce "/var/lib/acme/wildcard.pierdol.ing/fullchain.pem";
      sslCertificateKey = lib.mkForce "/var/lib/acme/wildcard.pierdol.ing/key.pem";
    };
  };
}
