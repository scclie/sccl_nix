{ config, lib, pkgs, ... }:
let
  cfg = config.sccl.minecraft;
  canonicalUuid = value: builtins.match "[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}" value != null;
  minecraftName = value: builtins.match "[A-Za-z0-9_]{3,16}" value != null;
  normalizedNames = map (operator: lib.toLower operator.name) cfg.operators;
  operatorUuids = map (operator: operator.uuid) cfg.operators;
  pierdolauthReleaseJar = pkgs.fetchurl {
    name = "pierdol-auth-paper-${cfg.pierdolAuth.version}.jar";
    url = "https://git.sccl.cc/scclie/pierdol-auth-paper/releases/download/v${cfg.pierdolAuth.version}/pierdol-auth-paper-${cfg.pierdolAuth.version}.jar";
    hash = cfg.pierdolAuth.hash;
  };
  protocolLibReleaseJar = pkgs.fetchurl {
    name = "ProtocolLib-${cfg.protocolLib.version}.jar";
    url = "https://github.com/dmulloy2/ProtocolLib/releases/download/dev-build/ProtocolLib.jar";
    hash = cfg.protocolLib.hash;
  };
  invSeeReleaseJar = pkgs.fetchurl {
    name = "InvSee++-${cfg.invSee.version}.jar";
    url = "https://cdn.modrinth.com/data/bYazc7fd/versions/LmdQx1rG/InvSee%2B%2B.jar";
    hash = cfg.invSee.hash;
  };

  # fucking dpi keeps screwing up plugin downloads from spiget.org
  # couldn't fix this shit with zapret, and i don't wanna run a full vpn just yet
  # so i came up with this janky-ass workaround THAT ACTUALLY FUCKING WORKS
  # basically, it downloads files in parallel 8kb chunks,
  # stitches them back together, then checks the hash 🤯
  fastLoginReleaseJar = pkgs.runCommand "FastLogin-${cfg.fastLogin.version}.jar" {
    url = "https://api.spiget.org/v2/resources/134322/download?version=636152";
    nativeBuildInputs = [ pkgs.curl pkgs.coreutils pkgs.gnugrep pkgs.gnused ];
    CURL_CA_BUNDLE = "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt";
    impureEnvVars = lib.fetchers.proxyImpureEnvVars;
    outputHash = cfg.fastLogin.hash;
    outputHashAlgo = "sha256";
    outputHashMode = "flat";
    preferLocalBuild = true;
  } ''
    set -euo pipefail
    curl --disable --fail --silent --show-error --location --head \
      --connect-timeout 5 --max-time 15 --retry 2 --retry-delay 1 --retry-all-errors \
      "$url" | tr -d '\r' > headers
    size=$(sed -n 's/^[Cc]ontent-[Ll]ength: *\([0-9]*\).*/\1/p' headers | tail -n 1)
    if [[ ! $size =~ ^[0-9]+$ ]] || (( size <= 0 || size > 20971520 )); then
      echo "FastLogin: missing or invalid CDN content length" >&2
      exit 1
    fi

    echo "FastLogin: downloading $size bytes in 8192-byte ranges"
    mkdir parts
    export size url
    seq 0 $(((size - 1) / 8192)) | xargs -P 4 -n 1 bash -c '
      set -euo pipefail
      index=$1
      start=$((index * 8192))
      end=$((start + 8191))
      if (( end >= size )); then end=$((size - 1)); fi
      printf -v part "%06d" "$index"

      code=$(curl --disable --fail --silent --show-error --location \
        --connect-timeout 5 --max-time 10 --retry 2 --retry-delay 1 --retry-all-errors \
        --max-filesize 8192 --range "$start-$end" \
        --dump-header "parts/$part.headers" --output "parts/$part.part" \
        --write-out "%{http_code}" "$url")
      [[ $code == 206 ]]
      range=$(tr -d "\r" < "parts/$part.headers" | grep -i "^content-range:" | tail -n 1)
      printf "%s\n" "$range" | grep -Fxiq "Content-Range: bytes $start-$end/$size"
      [[ $(stat -c %s "parts/$part.part") -eq $((end - start + 1)) ]]
    ' _

    cat parts/*.part > "$out"
    [[ $(stat -c %s "$out") -eq $size ]]

  '';
  fastLoginConfig = pkgs.writeText "skyblock-fastlogin-config.yml" ''
    premiumUuid: true
    autoRegister: false
    nameChangeCheck: false
    autoLogin: true
    secondAttemptCracked: false
    switchMode: false
  '';
  # !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  eula = pkgs.writeText "skyblock-eula.txt" "eula=true\n";
  serverProperties = pkgs.writeText "skyblock-server.properties" ''
    server-port=${toString cfg.port}
    online-mode=false
    white-list=true
    enforce-whitelist=true
    motd=\u00A7bskyblock\u00A76::\u00A73draumur \u00A74(closed test)
  '';
  operatorsJson = pkgs.writeText "skyblock-ops.json" (builtins.toJSON cfg.operators);
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
    pierdolAuth = {
      version = lib.mkOption {
        type = lib.types.strMatching "[0-9]+\\.[0-9]+\\.[0-9]+";
        description = "pinned PierdolAuth Forgejo release version without the v prefix.";
      };
      hash = lib.mkOption {
        type = lib.types.strMatching "sha256-[A-Za-z0-9+/]{43}=";
        #              сри ща
        description = "sri sha-256 hash of the pinned PierdolAuth release jar.";
      };
    };
    protocolLib = {
      version = lib.mkOption {
        type = lib.types.str;
        description = "pinned ProtocolLib release version label.";
      };
      hash = lib.mkOption {
        type = lib.types.strMatching "sha256-[A-Za-z0-9+/]{43}=";
        description = "sri sha-256 hash of the pinned ProtocolLib release jar.";
      };
    };
    fastLogin = {
      version = lib.mkOption {
        type = lib.types.str;
        description = "pinned FastLogin release version label.";
      };
      hash = lib.mkOption {
        type = lib.types.strMatching "sha256-[A-Za-z0-9+/]{43}=";
        description = "sri sha-256 hash of the pinned FastLogin release jar.";
      };
    };
    invSee = {
      version = lib.mkOption {
        type = lib.types.strMatching "[0-9]+\\.[0-9]+\\.[0-9]+";
        description = "pinned InvSee++ release version label.";
      };
      hash = lib.mkOption {
        type = lib.types.strMatching "sha256-[A-Za-z0-9+/]{43}=";
        description = "sri sha-256 hash of the pinned InvSee++ release jar.";
      };
    };
    operators = lib.mkOption {
      type = lib.types.listOf (lib.types.submodule {
        options = {
          uuid = lib.mkOption { type = lib.types.str; };
          name = lib.mkOption { type = lib.types.str; };
          level = lib.mkOption { type = lib.types.ints.between 1 4; default = 4; };
          bypassesPlayerLimit = lib.mkOption { type = lib.types.bool; default = true; };
        };
      });
      default = [];
      description = "Authoritative licensed Minecraft Paper operator records.";
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
      { assertion = builtins.all (operator: canonicalUuid operator.uuid) cfg.operators;
        message = "sccl.minecraft.operators UUIDs must use canonical lowercase hyphenated Mojang UUID format."; }
      { assertion = builtins.all (operator: minecraftName operator.name) cfg.operators;
        message = "sccl.minecraft.operators names must be 3-16 ASCII letters, digits, or underscores."; }
      { assertion = lib.length (lib.unique operatorUuids) == lib.length operatorUuids;
        message = "sccl.minecraft.operators UUIDs must be unique."; }
      { assertion = lib.length (lib.unique normalizedNames) == lib.length normalizedNames;
        message = "sccl.minecraft.operators names must be unique case-insensitively."; }
    ];

    networking.firewall.allowedTCPPorts = [ cfg.port ];

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
        set +x
        set -euo pipefail
        if ! test -f ${lib.escapeShellArg cfg.paperJar}; then
          echo ${lib.escapeShellArg "skyblock-paper: missing regular file ${cfg.paperJar}"} >&2
          exit 1
        fi

        # run as skyblock:skyblock
        temporary=""
        trap 'unset server_credential api_token; if [ -n "$temporary" ]; then rm -f -- "$temporary"; fi' EXIT

        plugin_jar_directory="$(dirname -- ${lib.escapeShellArg cfg.pluginJar})"
        temporary="$(mktemp "$plugin_jar_directory/.Pierdolauth.jar.XXXXXX")"
        install -m 0640 ${lib.escapeShellArg pierdolauthReleaseJar} "$temporary"
        mv -f -- "$temporary" ${lib.escapeShellArg cfg.pluginJar}
        temporary=""

        temporary="$(mktemp ${lib.escapeShellArg "${cfg.dataDir}/plugins/.ProtocolLib.jar.XXXXXX"})"
        install -m 0640 ${lib.escapeShellArg protocolLibReleaseJar} "$temporary"
        mv -f -- "$temporary" ${lib.escapeShellArg "${cfg.dataDir}/plugins/ProtocolLib.jar"}
        temporary=""

        temporary="$(mktemp ${lib.escapeShellArg "${cfg.dataDir}/plugins/.FastLogin.jar.XXXXXX"})"
        install -m 0640 ${lib.escapeShellArg fastLoginReleaseJar} "$temporary"
        mv -f -- "$temporary" ${lib.escapeShellArg "${cfg.dataDir}/plugins/FastLogin.jar"}
        temporary=""

        temporary="$(mktemp ${lib.escapeShellArg "${cfg.dataDir}/plugins/.InvSee++.jar.XXXXXX"})"
        install -m 0640 ${lib.escapeShellArg invSeeReleaseJar} "$temporary"
        mv -f -- "$temporary" ${lib.escapeShellArg "${cfg.dataDir}/plugins/InvSee++.jar"}
        temporary=""

        temporary="$(mktemp ${lib.escapeShellArg "${cfg.dataDir}/.ops.json.XXXXXX"})"
        install -m 0640 ${operatorsJson} "$temporary"
        mv -f -- "$temporary" ${lib.escapeShellArg "${cfg.dataDir}/ops.json"}
        temporary=""

        #
        # core protect later
        #

        install -d -m 0750 ${lib.escapeShellArg "${cfg.dataDir}/plugins/FastLogin"}
        temporary="$(mktemp ${lib.escapeShellArg "${cfg.dataDir}/plugins/FastLogin/config.yml.XXXXXX"})"
        install -m 0640 ${fastLoginConfig} "$temporary"
        mv -f -- "$temporary" ${lib.escapeShellArg "${cfg.dataDir}/plugins/FastLogin/config.yml"}
        temporary=""

        if ! test -f ${lib.escapeShellArg cfg.pluginJar}; then
          echo ${lib.escapeShellArg "skyblock-paper: missing regular file ${cfg.pluginJar}"} >&2
          exit 1
        fi
        if ! test -r "$CREDENTIALS_DIRECTORY/pierdolauth-server-credential"; then
          echo "skyblock-paper: required credential is not readable" >&2
          exit 1
        fi

        unset server_credential api_token
        server_credential=""
        if IFS= read -r -d "" server_credential < "$CREDENTIALS_DIRECTORY/pierdolauth-server-credential"; then
          unset server_credential
          exit 1
        fi
        case "$server_credential" in
          skyblock:?*) ;;
          *) unset server_credential; exit 1 ;;
        esac
        api_token="''${server_credential#skyblock:}"
        unset server_credential
        case "$api_token" in
          *:*|*$'\n'*|*$'\r'*) unset api_token; exit 1 ;;
        esac
        temporary="$(mktemp "$RUNTIME_DIRECTORY/pierdolauth-api-token.XXXXXX")"
        if ! printf '%s' "$api_token" > "$temporary"; then
          unset api_token
          exit 1
        fi
        unset api_token
        chmod 0400 "$temporary"
        mv -f -- "$temporary" "$RUNTIME_DIRECTORY/pierdolauth-api-token"
        temporary=""

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
        credential-file: $RUNTIME_DIRECTORY/pierdolauth-api-token
        whitelist-sync-seconds: 60
        session-lease-seconds: 60
        login-command: login
        EOF
        mv -f -- "$temporary" ${lib.escapeShellArg "${cfg.dataDir}/plugins/PierdolAuth/config.yml"}
        temporary=""
      '';
      restartTriggers = [ pierdolauthReleaseJar protocolLibReleaseJar fastLoginReleaseJar invSeeReleaseJar operatorsJson ];
      serviceConfig = {
        WorkingDirectory = cfg.dataDir;
        User = "skyblock";
        Group = "skyblock";
        LoadCredential = [ "pierdolauth-server-credential:${config.sops.secrets."mine-platform/game-auth-server-credentials".path}" ];
        RuntimeDirectory = "skyblock-paper";
        RuntimeDirectoryMode = "0700";
        RuntimeDirectoryPreserve = false;
        ExecStart = "${pkgs.jdk25}/bin/java -Xms1G -Xmx2G -jar ${cfg.paperJar} --nogui";
        Restart = "on-failure";
        RestartSec = "10s";
        TimeoutStopSec = "60s";
        UMask = "0077";
        NoNewPrivileges = true;
        PrivateTmp = true;
        PrivateDevices = true;
        ProtectKernelTunables = true;
        ProtectKernelModules = true;
        ProtectControlGroups = true;
        RestrictSUIDSGID = true;
        LockPersonality = true;
        RestrictRealtime = true;
        RemoveIPC = true;
        SystemCallArchitectures = "native";
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
