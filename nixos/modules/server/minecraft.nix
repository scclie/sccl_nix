{ config, lib, pkgs, ... }:
let
  cfg = config.sccl.minecraft;
  eula = pkgs.writeText "skyblock-eula.txt" "eula=true\n";
  serverProperties = pkgs.writeText "skyblock-server.properties" ''
    server-port=${toString cfg.port}
    online-mode=false
    white-list=true
    enforce-whitelist=true
    motd=Skyblock (closed test)
  '';
in {
  options.sccl.minecraft = {
    enable = lib.mkEnableOption "Skyblock Paper server";
    dataDir = lib.mkOption {
      type = lib.types.str;
      default = "/tank/minecraft/skyblock";
    };
    port = lib.mkOption {
      type = lib.types.port;
      default = 25565;
    };
    paperJar = lib.mkOption {
      type = lib.types.str;
      default = "${cfg.dataDir}/paper-26.3.jar";
    };
    pluginJar = lib.mkOption {
      type = lib.types.str;
      default = "${cfg.dataDir}/plugins/Pierdolauth.jar";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      { assertion = config.sccl.minePlatform.enable;
        message = "sccl.minecraft requires sccl.minePlatform.enable."; }
      { assertion = cfg.dataDir == "/tank/minecraft/skyblock";
        message = "sccl.minecraft.dataDir must be /tank/minecraft/skyblock."; }
      { assertion = cfg.port == 25565;
        message = "sccl.minecraft.port must be 25565."; }
    ];

    users.groups.skyblock = { };
    users.users.skyblock = {
      isSystemUser = true;
      group = "skyblock";
      home = cfg.dataDir;
      createHome = false;
      description = "Skyblock Paper server";
    };
    systemd.tmpfiles.rules = [
      "d ${cfg.dataDir} 0750 skyblock skyblock -"
      "d ${cfg.dataDir}/plugins 0750 skyblock skyblock -"
    ];

    systemd.services.skyblock-paper = {
      description = "Skyblock Paper 26.3 server (closed test)";
      wantedBy = [ "multi-user.target" ];
      after = [ "network-online.target" "docker-mine-platform.service" "sops-install-secrets.service" ];
      wants = [ "network-online.target" "docker-mine-platform.service" "sops-install-secrets.service" ];
      path = [ pkgs.coreutils ];
      preStart = ''
        set -euo pipefail
        if ! test -f ${lib.escapeShellArg cfg.paperJar}; then
          echo ${lib.escapeShellArg "skyblock-paper: missing regular file ${cfg.paperJar}"} >&2
          exit 1
        fi
        if ! test -f ${lib.escapeShellArg cfg.pluginJar}; then
          echo ${lib.escapeShellArg "skyblock-paper: missing regular file ${cfg.pluginJar}"} >&2
          exit 1
        fi
        if ! test -r "$CREDENTIALS_DIRECTORY/pierdolauth-api-token"; then
          echo "skyblock-paper: required credential is not readable" >&2
          exit 1
        fi

        # run as skyblock:skyblock
        temporary=""
        trap 'if [ -n "$temporary" ]; then rm -f -- "$temporary"; fi' EXIT
        temporary="$(mktemp ${lib.escapeShellArg "${cfg.dataDir}/eula.txt.XXXXXX"})"
        install -m 0640 ${eula} "$temporary"
        mv -f -- "$temporary" ${lib.escapeShellArg "${cfg.dataDir}/eula.txt"}

        temporary="$(mktemp ${lib.escapeShellArg "${cfg.dataDir}/server.properties.XXXXXX"})"
        install -m 0640 ${serverProperties} "$temporary"
        mv -f -- "$temporary" ${lib.escapeShellArg "${cfg.dataDir}/server.properties"}

        install -d -m 0750 ${lib.escapeShellArg "${cfg.dataDir}/plugins/PierdolAuth"}
        temporary="$(mktemp ${lib.escapeShellArg "${cfg.dataDir}/plugins/PierdolAuth/config.yml.XXXXXX"})"
        install -m 0640 /dev/null "$temporary"
        cat > "$temporary" <<EOF
        server-id: skyblock
        api-base-url: http://127.0.0.1:8088/internal/game-auth/v1
        credential-file: $CREDENTIALS_DIRECTORY/pierdolauth-api-token
        whitelist-sync-seconds: 60
        session-lease-seconds: 120
        login-command: login
        EOF
        mv -f -- "$temporary" ${lib.escapeShellArg "${cfg.dataDir}/plugins/PierdolAuth/config.yml"}
        temporary=""
      '';
      serviceConfig = {
        WorkingDirectory = cfg.dataDir;
        User = "skyblock";
        Group = "skyblock";
        LoadCredential = [ "pierdolauth-api-token:${config.sops.secrets."mine-platform/game-auth-server-credentials".path}" ];
        ExecStart = "${pkgs.jdk25}/bin/java -Xms1G -Xmx2G -jar ${cfg.paperJar} --nogui";
        Restart = "on-failure";
        RestartSec = "10s";
        TimeoutStopSec = "60s";
        UMask = "0077";
        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectHome = true;
        ProtectSystem = "strict";
        ReadWritePaths = [ cfg.dataDir ];
        InaccessiblePaths = [ "/nix/var/nix/daemon-socket" ];
        LimitCORE = 0;
        CapabilityBoundingSet = "";
        RestrictAddressFamilies = [ "AF_UNIX" "AF_INET" "AF_INET6" ];
      };
    };
  };
}
