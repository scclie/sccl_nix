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
  pierdolChatReleaseJar = pkgs.fetchurl {
    name = "PierdolChat-${cfg.pierdolChat.version}.jar";
    url = "https://git.sccl.cc/scclie/pierdol-chat-paper/releases/download/v${cfg.pierdolChat.version}/pierdol-chat-paper-${cfg.pierdolChat.version}.jar";
    hash = cfg.pierdolChat.hash;
  };
  pierdolPlaytimeReleaseJar = pkgs.fetchurl {
    name = "PierdolPlaytime-${cfg.pierdolPlaytime.version}.jar";
    url = "https://git.sccl.cc/scclie/pierdol-playtime-paper/releases/download/v${cfg.pierdolPlaytime.version}/pierdol-playtime-paper-${cfg.pierdolPlaytime.version}.jar";
    hash = cfg.pierdolPlaytime.hash;
  };
  pierdolChatConfig = pkgs.writeText "skyblock-pierdolchat-config.yml" ''
    global-prefix: '<dark_green>[G]</dark_green>'
    local-prefix: '<gold>[L]</gold>'
    local-radius: 100
    name-formats:
      overworld: '<gradient:#88c0d0:#a3be8c><name></gradient>'
      nether: '<gradient:#d08770:#ebcb8b><name></gradient>'
      end: '<gradient:#b48ead:#81a1c1><name></gradient>'
  '';
  protocolLibReleaseJar = pkgs.fetchurl {
    name = "ProtocolLib-${cfg.protocolLib.version}.jar";
    url = "https://github.com/dmulloy2/ProtocolLib/releases/download/dev-build/ProtocolLib.jar";
    hash = cfg.protocolLib.hash;
  };
  placeholderApiReleaseJar = pkgs.fetchurl {
    name = "PlaceholderAPI-${cfg.placeholderApi.version}.jar";
    url = cfg.placeholderApi.url;
    hash = cfg.placeholderApi.hash;
  };
  interactiveChatReleaseJar = pkgs.fetchurl {
    name = "InteractiveChat-${cfg.interactiveChat.version}.jar";
    url = cfg.interactiveChat.url;
    hash = cfg.interactiveChat.hash;
  };
  vaultReleaseJar = pkgs.fetchurl {
    name = "Vault-${cfg.vault.version}.jar";
    url = cfg.vault.url;
    hash = cfg.vault.hash;
  };
  invSeeReleaseJar = pkgs.fetchurl {
    name = "InvSee++-${cfg.invSee.version}.jar";
    url = "https://cdn.modrinth.com/data/bYazc7fd/versions/LmdQx1rG/InvSee%2B%2B.jar";
    hash = cfg.invSee.hash;
  };
  tabReleaseJar = pkgs.fetchurl {
    name = "TAB-${cfg.tab.version}.jar";
    url = "https://cdn.modrinth.com/data/gG7VFbG0/versions/HlsRTW5F/TAB%20v6.2.1.jar";
    hash = cfg.tab.hash;
  };
  simpleAutoRestartReleaseJar = pkgs.fetchurl {
    name = "SimpleAutoRestart-${cfg.simpleAutoRestart.version}.jar";
    url = "https://cdn.modrinth.com/data/6lYow9VP/versions/h6nbB8OX/SimpleAutoRestart-${cfg.simpleAutoRestart.version}.jar";
    hash = cfg.simpleAutoRestart.hash;
  };
  worldEditReleaseJar = pkgs.fetchurl {
    name = "worldedit-bukkit-${cfg.worldEdit.version}.jar";
    url = cfg.worldEdit.url;
    hash = cfg.worldEdit.hash;
  };
  skinsRestorerReleaseJar = pkgs.fetchurl {
    name = "SkinsRestorer-${cfg.skinsRestorer.version}.jar";
    url = cfg.skinsRestorer.url;
    hash = cfg.skinsRestorer.hash;
  };
  gsitReleaseJar = pkgs.fetchurl {
    name = "GSit-${cfg.gsit.version}.jar";
    url = cfg.gsit.url;
    hash = cfg.gsit.hash;
  };
  inventoryRollbackPlusReleaseJar = pkgs.fetchurl {
    name = "InventoryRollbackPlus-${cfg.inventoryRollbackPlus.version}.jar";
    url = cfg.inventoryRollbackPlus.url;
    hash = cfg.inventoryRollbackPlus.hash;
  };
  inventoryRollbackPlusJar = pkgs.runCommand "InventoryRollbackPlus-${cfg.inventoryRollbackPlus.version}-op-only.jar" {
    nativeBuildInputs = [ pkgs.python3 ];
  } ''
    python3 - ${inventoryRollbackPlusReleaseJar} "$out" <<'PY'
    import re
    import sys
    import zipfile

    with zipfile.ZipFile(sys.argv[1]) as source, zipfile.ZipFile(sys.argv[2], 'w') as target:
        for entry in source.infolist():
            data = source.read(entry.filename)
            if entry.filename == 'plugin.yml':
                text = data.decode('utf-8')
                command = '  inventoryrollbackplus:\n'
                if text.count(command) != 1:
                    raise RuntimeError('InventoryRollbackPlus command metadata changed')
                text = text.replace(command, command + '    permission: inventoryrollbackplus.cmd\n', 1)
                for node in ('cmd', 'help', 'version'):
                    pattern = r'(?m)(^  inventoryrollbackplus\.' + node + r':\n(?:    .*\n)*?    default: )true$'
                    text, count = re.subn(pattern, r'\1op', text)
                    if count != 1:
                        raise RuntimeError('InventoryRollbackPlus permission metadata changed: ' + node)
                data = text.encode('utf-8')
            target.writestr(entry, data)
    PY
  '';
  serverRulesPack = pkgs.linkFarm "skyblock-server-rules-datapack" [
    {
      name = "pack.mcmeta";
      path = pkgs.writeText "skyblock-server-rules-pack.mcmeta" (builtins.toJSON {
        pack = { description = "Declarative server gamerules"; min_format = 121; max_format = 121; };
      });
    }
    {
      name = "data/minecraft/tags/function/load.json";
      path = pkgs.writeText "skyblock-server-rules-load.json" (builtins.toJSON {
        values = [ "sccl:server_rules" ];
      });
    }
    {
      name = "data/sccl/function/server_rules.mcfunction";
      path = pkgs.writeText "skyblock-server-rules.mcfunction" ''
        gamerule minecraft:players_sleeping_percentage ${toString cfg.playersSleepingPercentage}
      '';
    }
  ];
  craftableInvFramesReleaseJar = pkgs.fetchurl {
    name = "craftableinvframes-${cfg.craftableInvFrames.version}.jar";
    url = cfg.craftableInvFrames.url;
    hash = cfg.craftableInvFrames.hash;
  };
  craftableInvFramesConfig = pkgs.writeText "skyblock-craftableinvframes-config.yml" ''
    item-frames-glow: true
    recipe:
      ==: org.bukkit.inventory.ItemStack
      DataVersion: 5023
      id: minecraft:${lib.toLower cfg.craftableInvFrames.recipeIngredient}
      count: 1
      schema_version: 1
  '';
  simpleVoiceChatReleaseJar = pkgs.fetchurl {
    name = "voicechat-bukkit-${cfg.simpleVoiceChat.version}.jar";
    url = cfg.simpleVoiceChat.url;
    hash = cfg.simpleVoiceChat.hash;
  };
  discordSrvReleaseJar = pkgs.fetchurl {
    name = "DiscordSRV-${cfg.discordSrv.version}.jar";
    url = cfg.discordSrv.url;
    hash = cfg.discordSrv.hash;
  };
  discordSrvConfig = pkgs.writeText "skyblock-discordsrv-config.yml" ''
    ConfigVersion: ${cfg.discordSrv.version}
    BotToken: ""
    Channels: ${builtins.toJSON (lib.optionalAttrs (cfg.discordSrv.channelId != null) { global = cfg.discordSrv.channelId; })}
    DiscordConsoleChannelId: ""
    UseModernPaperChatEvent: true
    Experiment_WebhookChatMessageDelivery: true
    Experiment_WebhookChatMessageUsernameFormat: "%username%"
    Experiment_WebhookChatMessageFormat: "%message%"
    Experiment_WebhookChatMessageUsernameFromDiscord: false
    Experiment_WebhookChatMessageAvatarFromDiscord: false
    DiscordChatChannelDiscordToMinecraft: true
    DiscordChatChannelMinecraftToDiscord: true
    DiscordChatChannelPrefixRequiredToProcessMessage: ""
    DiscordChatChannelPrefixActsAsBlacklist: false
    DiscordChatChannelRequireLinkedAccount: false
    DiscordChatChannelBlockBots: true
    DiscordChatChannelBlockWebhooks: true
    DiscordChatChannelBlockedIds: []
    DiscordChatChannelBlockedRolesIds: []
    DiscordChatChannelTranslateMentions: false
    DiscordChatChannelAllowedMentions: []
    DiscordChatChannelRolesAllowedToUseColorCodesInChat: []
    DiscordChatChannelBroadcastDiscordMessagesToConsole: false
    DiscordChatChannelConsoleCommandEnabled: false
    DiscordChatChannelListCommandEnabled: false
    DiscordCannedResponses: {}
    MinecraftDiscordAccountLinkedRoleNameToAddUserTo: ""
    MinecraftDiscordAccountLinkedConsoleCommands: []
    MinecraftDiscordAccountUnlinkedConsoleCommands: []
    ServerWatchdogEnabled: false
    ChannelTopicUpdaterChannelTopicsAtShutdownEnabled: false
    ChannelTopicUpdaterRateInMinutes: 0
    ChannelUpdater: []
    Debug: []
  '';
  discordSrvMessages = pkgs.writeText "skyblock-discordsrv-messages.yml" ''
    MinecraftPlayerJoinMessage:
      Enabled: true
    MinecraftPlayerFirstJoinMessage:
      Enabled: false
    MinecraftPlayerLeaveMessage:
      Enabled: true
    MinecraftPlayerDeathMessage:
      Enabled: true
    MinecraftPlayerAchievementMessage:
      Enabled: false
    DiscordChatChannelServerStartupMessage: ""
    DiscordChatChannelServerShutdownMessage: ""
    ChannelTopicUpdaterChatChannelTopicFormat: ""
    ChannelTopicUpdaterConsoleChannelTopicFormat: ""
  '';
  discordSrvSynchronization = pkgs.writeText "skyblock-discordsrv-synchronization.yml" ''
    NicknameSynchronizationEnabled: false
    GroupRoleSynchronizationGroupsAndRolesToSync: {}
    BanSynchronizationDiscordToMinecraft: false
    BanSynchronizationMinecraftToDiscord: false
  '';
  simpleVoiceChatConfig = pkgs.writeText "skyblock-voicechat-server.properties" ''
    port=24454
    voice_host=
    check_for_updates=false
  '';
  simpleAutoRestartConfig = pkgs.writeText "skyblock-simpleautorestart-config.yml" ''
    restartTime:
      - "Daily;05:00"
    messages:
      "300": "<yellow>daily restart in 5 min"
      "180": "<yellow>daily restart in 3 min"
      "120": "<yellow>daily restart in 2 min"
      "60": "<yellow>daily restart in 1 min"
      "30": "<yellow>daily restart in 30 sec"
      "10": "<red>daily restart in 10 sec!"
      "5": "<red>daily restart in 5 seconds!"
      "4": "<red>4"
      "3": "<red>3"
      "2": "<red>2"
      "1": "<red>1"
      "0": "<red>restarting now; pls reconnect shortly."
    titles:
      "3": "<bold><dark_red>restarting"
    subtitles:
      "3": "<gold>Please reconnect shortly"
    commands:
      - "minecraft:stop"
  '';
  tabConfig = pkgs.writeText "skyblock-tab-config.yml" ''
    header-footer:
      enabled: true
      designs:
        default:
          header:
            - "<#81a1c1>draumur</#b48ead>"
            - ""
          footer:
            - ""
            - "<#d8dee9>mine.pierdol.ing"
            - "<#d8dee9>online: %online%/20    ping: %ping%ms    tps: %tps%"
    tablist-name-formatting:
      enabled: false
    scoreboard-teams:
      enabled: false
    playerlist-objective:
      enabled: false
    belowname-objective:
      enabled: false
    prevent-spectator-effect:
      enabled: false
    bossbar:
      enabled: false
    scoreboard:
      enabled: false
    layout:
      enabled: false
    ping-spoof:
      enabled: false
    global-playerlist:
      enabled: false
    per-world-playerlist:
      enabled: false
    proxy-support:
      enabled: false
    mysql:
      enabled: false
    placeholders:
      register-tab-expansion: false
    components:
      minimessage-support: true
      disable-shadow-for-heads: false
    assign-groups-by-permissions: false
    use-bukkit-permissions-manager: false
    compensate-for-packetevents-bug: false
    debug: false
    config-version: 7
  '';

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
    allow-flight=true
    view-distance=24
    spawn-protection=0
    online-mode=false
    white-list=true
    enforce-whitelist=true
    motd=\u00A7bskyblock\u00A76::\u00A73draumur
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
    playersSleepingPercentage = lib.mkOption {
      type = lib.types.ints.between 0 100;
      default = 100;
      description = "Percentage of players required to sleep, applied by a world-load datapack.";
    };
    gsit = {
      version = lib.mkOption {
        type = lib.types.str;
        description = "pinned GSit release version.";
      };
      url = lib.mkOption {
        type = lib.types.str;
        description = "artifact URL of the pinned GSit release jar.";
      };
      hash = lib.mkOption {
        type = lib.types.strMatching "sha256-[A-Za-z0-9+/]{43}=";
        description = "sri sha-256 hash of the pinned GSit release jar.";
      };
    };
    inventoryRollbackPlus = {
      version = lib.mkOption {
        type = lib.types.str;
        description = "pinned InventoryRollbackPlus release version.";
      };
      url = lib.mkOption {
        type = lib.types.str;
        description = "artifact URL of the pinned InventoryRollbackPlus release jar.";
      };
      hash = lib.mkOption {
        type = lib.types.strMatching "sha256-[A-Za-z0-9+/]{43}=";
        description = "sri sha-256 hash of the upstream InventoryRollbackPlus release jar, before the OP-only metadata patch.";
      };
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
    pierdolChat = {
      version = lib.mkOption {
        type = lib.types.strMatching "[0-9]+\\.[0-9]+\\.[0-9]+";
        description = "pinned PierdolChat Forgejo release version without the v prefix.";
      };
      hash = lib.mkOption {
        type = lib.types.strMatching "sha256-[A-Za-z0-9+/]{43}=";
        description = "sri sha-256 hash of the pinned PierdolChat release jar.";
      };
    };
    pierdolPlaytime = {
      version = lib.mkOption {
        type = lib.types.strMatching "[0-9]+\\.[0-9]+\\.[0-9]+";
        description = "pinned PierdolPlaytime Forgejo release version without the v prefix.";
      };
      hash = lib.mkOption {
        type = lib.types.strMatching "sha256-[A-Za-z0-9+/]{43}=";
        description = "sri sha-256 hash of the pinned PierdolPlaytime release jar.";
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
    placeholderApi = {
      version = lib.mkOption {
        type = lib.types.str;
        description = "pinned PlaceholderAPI release version.";
      };
      url = lib.mkOption {
        type = lib.types.str;
        description = "artifact URL of the pinned PlaceholderAPI release jar.";
      };
      hash = lib.mkOption {
        type = lib.types.strMatching "sha256-[A-Za-z0-9+/]{43}=";
        description = "sri sha-256 hash of the pinned PlaceholderAPI release jar.";
      };
    };
    interactiveChat = {
      version = lib.mkOption {
        type = lib.types.str;
        description = "pinned InteractiveChat release version.";
      };
      url = lib.mkOption {
        type = lib.types.str;
        description = "artifact URL of the pinned InteractiveChat release jar.";
      };
      hash = lib.mkOption {
        type = lib.types.strMatching "sha256-[A-Za-z0-9+/]{43}=";
        description = "sri sha-256 hash of the pinned InteractiveChat release jar.";
      };
    };
    vault = {
      version = lib.mkOption {
        type = lib.types.str;
        description = "pinned Vault release version.";
      };
      url = lib.mkOption {
        type = lib.types.str;
        description = "artifact URL of the pinned Vault release jar.";
      };
      hash = lib.mkOption {
        type = lib.types.strMatching "sha256-[A-Za-z0-9+/]{43}=";
        description = "sri sha-256 hash of the pinned Vault release jar.";
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
    tab = {
      version = lib.mkOption {
        type = lib.types.strMatching "[0-9]+\\.[0-9]+\\.[0-9]+";
        description = "pinned TAB release version label.";
      };
      hash = lib.mkOption {
        type = lib.types.strMatching "sha256-[A-Za-z0-9+/]{43}=";
        description = "sri sha-256 hash of the pinned TAB release jar.";
      };
    };
    simpleAutoRestart = {
      version = lib.mkOption {
        type = lib.types.strMatching "2\\.11\\.6";
        description = "pinned Simple Auto Restart version for Modrinth release h6nbB8OX.";
      };
      hash = lib.mkOption {
        type = lib.types.strMatching "sha256-[A-Za-z0-9+/]{43}=";
        description = "sri sha-256 hash of the pinned Simple Auto Restart release jar.";
      };
    };
    simpleVoiceChat = {
      version = lib.mkOption {
        type = lib.types.str;
        description = "pinned Simple Voice Chat release version label.";
      };
      url = lib.mkOption {
        type = lib.types.str;
        description = "artifact URL of the pinned Simple Voice Chat release jar.";
      };
      hash = lib.mkOption {
        type = lib.types.strMatching "sha256-[A-Za-z0-9+/]{43}=";
        description = "sri sha-256 hash of the pinned Simple Voice Chat release jar.";
      };
    };
    discordSrv = {
      channelId = lib.mkOption {
        type = lib.types.nullOr (lib.types.strMatching "[0-9]{17,20}");
        default = null;
        description = "Discord text channel snowflake ID; null leaves chat routing unconfigured.";
      };
      version = lib.mkOption {
        type = lib.types.str;
        description = "pinned DiscordSRV release version label.";
      };
      url = lib.mkOption {
        type = lib.types.str;
        description = "artifact URL of the pinned DiscordSRV release jar.";
      };
      hash = lib.mkOption {
        type = lib.types.strMatching "sha256-[A-Za-z0-9+/]{43}=";
        description = "sri sha-256 hash of the pinned DiscordSRV release jar.";
      };
    };
    worldEdit = {
      version = lib.mkOption {
        type = lib.types.str;
        description = "pinned WorldEdit release version label.";
      };
      url = lib.mkOption {
        type = lib.types.str;
        description = "artifact URL of the pinned WorldEdit release jar.";
      };
      hash = lib.mkOption {
        type = lib.types.strMatching "sha256-[A-Za-z0-9+/]{43}=";
        description = "sri sha-256 hash of the pinned WorldEdit release jar.";
      };
    };
    craftableInvFrames = {
      version = lib.mkOption {
        type = lib.types.str;
        description = "pinned CraftableInvFrames release version.";
      };
      url = lib.mkOption {
        type = lib.types.str;
        description = "artifact URL of the pinned CraftableInvFrames release jar.";
      };
      hash = lib.mkOption {
        type = lib.types.strMatching "sha256-[A-Za-z0-9+/]{43}=";
        description = "sri sha-256 hash of the pinned CraftableInvFrames release jar.";
      };
      recipeIngredient = lib.mkOption {
        type = lib.types.strMatching "[A-Z][A-Z0-9_]*";
        default = "GLOW_INK_SAC";
        description = "Bukkit material for the center ingredient surrounded by eight item frames.";
      };
    };
    skinsRestorer = {
      version = lib.mkOption {
        type = lib.types.str;
        description = "pinned SkinsRestorer release version label.";
      };
      url = lib.mkOption {
        type = lib.types.str;
        description = "artifact URL of the pinned SkinsRestorer Paper/Bukkit release jar.";
      };
      hash = lib.mkOption {
        type = lib.types.strMatching "sha256-[A-Za-z0-9+/]{43}=";
        description = "sri sha-256 hash of the pinned SkinsRestorer release jar.";
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
    networking.firewall.allowedUDPPorts = [ 24454 ];

    users.groups.skyblock = { };
    sops.secrets."mine-platform/discord-bot-token" = {
      sopsFile = ../../../secrets/apps.yaml;
      mode = "0400";
      owner = "root";
    };
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
      restartIfChanged = false;
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

        # Paper 26.3 uses data pack format 121 and namespaced snake_case gamerules.
        # Manage only our own datapack; leave existing worlds and packs untouched.
        rules_directory=${lib.escapeShellArg "${cfg.dataDir}/world/datapacks/sccl-server-rules"}
        for relative in pack.mcmeta data/minecraft/tags/function/load.json data/sccl/function/server_rules.mcfunction; do
          target="$rules_directory/$relative"
          install -d -m 0750 "$(dirname -- "$target")"
          temporary="$(mktemp "$target.XXXXXX")"
          install -m 0640 ${serverRulesPack}/"$relative" "$temporary"
          mv -f -- "$temporary" "$target"
          temporary=""
        done

        temporary="$(mktemp ${lib.escapeShellArg "${cfg.dataDir}/plugins/.GSit.jar.XXXXXX"})"
        install -m 0640 ${lib.escapeShellArg gsitReleaseJar} "$temporary"
        mv -f -- "$temporary" ${lib.escapeShellArg "${cfg.dataDir}/plugins/GSit.jar"}
        temporary=""

        temporary="$(mktemp ${lib.escapeShellArg "${cfg.dataDir}/plugins/.InventoryRollbackPlus.jar.XXXXXX"})"
        install -m 0640 ${lib.escapeShellArg inventoryRollbackPlusJar} "$temporary"
        mv -f -- "$temporary" ${lib.escapeShellArg "${cfg.dataDir}/plugins/InventoryRollbackPlus.jar"}
        temporary=""

        plugin_jar_directory="$(dirname -- ${lib.escapeShellArg cfg.pluginJar})"
        temporary="$(mktemp "$plugin_jar_directory/.Pierdolauth.jar.XXXXXX")"
        install -m 0640 ${lib.escapeShellArg pierdolauthReleaseJar} "$temporary"
        mv -f -- "$temporary" ${lib.escapeShellArg cfg.pluginJar}
        temporary=""

        temporary="$(mktemp ${lib.escapeShellArg "${cfg.dataDir}/plugins/.PierdolChat.jar.XXXXXX"})"
        install -m 0640 ${lib.escapeShellArg pierdolChatReleaseJar} "$temporary"
        mv -f -- "$temporary" ${lib.escapeShellArg "${cfg.dataDir}/plugins/PierdolChat.jar"}
        temporary=""

        temporary="$(mktemp ${lib.escapeShellArg "${cfg.dataDir}/plugins/.PierdolPlaytime.jar.XXXXXX"})"
        install -m 0640 ${lib.escapeShellArg pierdolPlaytimeReleaseJar} "$temporary"
        mv -f -- "$temporary" ${lib.escapeShellArg "${cfg.dataDir}/plugins/PierdolPlaytime.jar"}
        temporary=""

        install -d -m 0750 ${lib.escapeShellArg "${cfg.dataDir}/plugins/PierdolChat"}
        temporary="$(mktemp ${lib.escapeShellArg "${cfg.dataDir}/plugins/PierdolChat/config.yml.XXXXXX"})"
        install -m 0640 ${pierdolChatConfig} "$temporary"
        mv -f -- "$temporary" ${lib.escapeShellArg "${cfg.dataDir}/plugins/PierdolChat/config.yml"}
        temporary=""

        temporary="$(mktemp ${lib.escapeShellArg "${cfg.dataDir}/plugins/.ProtocolLib.jar.XXXXXX"})"
        install -m 0640 ${lib.escapeShellArg protocolLibReleaseJar} "$temporary"
        mv -f -- "$temporary" ${lib.escapeShellArg "${cfg.dataDir}/plugins/ProtocolLib.jar"}
        temporary=""

        temporary="$(mktemp ${lib.escapeShellArg "${cfg.dataDir}/plugins/.PlaceholderAPI.jar.XXXXXX"})"
        install -m 0640 ${lib.escapeShellArg placeholderApiReleaseJar} "$temporary"
        mv -f -- "$temporary" ${lib.escapeShellArg "${cfg.dataDir}/plugins/PlaceholderAPI.jar"}
        temporary=""

        temporary="$(mktemp ${lib.escapeShellArg "${cfg.dataDir}/plugins/.Vault.jar.XXXXXX"})"
        install -m 0640 ${lib.escapeShellArg vaultReleaseJar} "$temporary"
        mv -f -- "$temporary" ${lib.escapeShellArg "${cfg.dataDir}/plugins/Vault.jar"}
        temporary=""

        temporary="$(mktemp ${lib.escapeShellArg "${cfg.dataDir}/plugins/.InteractiveChat.jar.XXXXXX"})"
        install -m 0640 ${lib.escapeShellArg interactiveChatReleaseJar} "$temporary"
        mv -f -- "$temporary" ${lib.escapeShellArg "${cfg.dataDir}/plugins/InteractiveChat.jar"}
        temporary=""

        temporary="$(mktemp ${lib.escapeShellArg "${cfg.dataDir}/plugins/.FastLogin.jar.XXXXXX"})"
        install -m 0640 ${lib.escapeShellArg fastLoginReleaseJar} "$temporary"
        mv -f -- "$temporary" ${lib.escapeShellArg "${cfg.dataDir}/plugins/FastLogin.jar"}
        temporary=""

        temporary="$(mktemp ${lib.escapeShellArg "${cfg.dataDir}/plugins/.InvSee++.jar.XXXXXX"})"
        install -m 0640 ${lib.escapeShellArg invSeeReleaseJar} "$temporary"
        mv -f -- "$temporary" ${lib.escapeShellArg "${cfg.dataDir}/plugins/InvSee++.jar"}
        temporary=""

        temporary="$(mktemp ${lib.escapeShellArg "${cfg.dataDir}/plugins/.TAB.jar.XXXXXX"})"
        install -m 0640 ${lib.escapeShellArg tabReleaseJar} "$temporary"
        mv -f -- "$temporary" ${lib.escapeShellArg "${cfg.dataDir}/plugins/TAB.jar"}
        temporary=""

        install -d -m 0750 ${lib.escapeShellArg "${cfg.dataDir}/plugins/TAB"}
        temporary="$(mktemp ${lib.escapeShellArg "${cfg.dataDir}/plugins/TAB/config.yml.XXXXXX"})"
        install -m 0640 ${tabConfig} "$temporary"
        mv -f -- "$temporary" ${lib.escapeShellArg "${cfg.dataDir}/plugins/TAB/config.yml"}
        temporary=""

        temporary="$(mktemp ${lib.escapeShellArg "${cfg.dataDir}/plugins/.SimpleAutoRestart.jar.XXXXXX"})"
        install -m 0640 ${lib.escapeShellArg simpleAutoRestartReleaseJar} "$temporary"
        mv -f -- "$temporary" ${lib.escapeShellArg "${cfg.dataDir}/plugins/SimpleAutoRestart.jar"}
        temporary=""

        install -d -m 0750 ${lib.escapeShellArg "${cfg.dataDir}/plugins/SimpleAutoRestart"}
        temporary="$(mktemp ${lib.escapeShellArg "${cfg.dataDir}/plugins/SimpleAutoRestart/config.yml.XXXXXX"})"
        install -m 0640 ${simpleAutoRestartConfig} "$temporary"
        mv -f -- "$temporary" ${lib.escapeShellArg "${cfg.dataDir}/plugins/SimpleAutoRestart/config.yml"}
        temporary=""

        temporary="$(mktemp ${lib.escapeShellArg "${cfg.dataDir}/plugins/.WorldEdit.jar.XXXXXX"})"
        install -m 0640 ${lib.escapeShellArg worldEditReleaseJar} "$temporary"
        mv -f -- "$temporary" ${lib.escapeShellArg "${cfg.dataDir}/plugins/WorldEdit.jar"}
        temporary=""

        temporary="$(mktemp ${lib.escapeShellArg "${cfg.dataDir}/plugins/.CraftableInvFrames.jar.XXXXXX"})"
        install -m 0640 ${lib.escapeShellArg craftableInvFramesReleaseJar} "$temporary"
        mv -f -- "$temporary" ${lib.escapeShellArg "${cfg.dataDir}/plugins/CraftableInvFrames.jar"}
        temporary=""

        install -d -m 0750 ${lib.escapeShellArg "${cfg.dataDir}/plugins/craftableinvframes"}
        temporary="$(mktemp ${lib.escapeShellArg "${cfg.dataDir}/plugins/craftableinvframes/config.yml.XXXXXX"})"
        install -m 0640 ${craftableInvFramesConfig} "$temporary"
        mv -f -- "$temporary" ${lib.escapeShellArg "${cfg.dataDir}/plugins/craftableinvframes/config.yml"}
        temporary=""

        temporary="$(mktemp ${lib.escapeShellArg "${cfg.dataDir}/plugins/.SkinsRestorer.jar.XXXXXX"})"
        install -m 0640 ${lib.escapeShellArg skinsRestorerReleaseJar} "$temporary"
        mv -f -- "$temporary" ${lib.escapeShellArg "${cfg.dataDir}/plugins/SkinsRestorer.jar"}
        temporary=""

        temporary="$(mktemp ${lib.escapeShellArg "${cfg.dataDir}/plugins/.voicechat.jar.XXXXXX"})"
        install -m 0640 ${lib.escapeShellArg simpleVoiceChatReleaseJar} "$temporary"
        mv -f -- "$temporary" ${lib.escapeShellArg "${cfg.dataDir}/plugins/voicechat.jar"}
        temporary=""

        temporary="$(mktemp ${lib.escapeShellArg "${cfg.dataDir}/plugins/.DiscordSRV.jar.XXXXXX"})"
        install -m 0640 ${lib.escapeShellArg discordSrvReleaseJar} "$temporary"
        mv -f -- "$temporary" ${lib.escapeShellArg "${cfg.dataDir}/plugins/DiscordSRV.jar"}
        temporary=""

        install -d -m 0750 ${lib.escapeShellArg "${cfg.dataDir}/plugins/DiscordSRV"}
        temporary="$(mktemp ${lib.escapeShellArg "${cfg.dataDir}/plugins/DiscordSRV/.token.XXXXXX"})"
        install -m 0400 "$CREDENTIALS_DIRECTORY/discord-bot-token" "$temporary"
        mv -f -- "$temporary" ${lib.escapeShellArg "${cfg.dataDir}/plugins/DiscordSRV/.token"}
        temporary=""

        temporary="$(mktemp ${lib.escapeShellArg "${cfg.dataDir}/plugins/DiscordSRV/config.yml.XXXXXX"})"
        install -m 0640 ${discordSrvConfig} "$temporary"
        mv -f -- "$temporary" ${lib.escapeShellArg "${cfg.dataDir}/plugins/DiscordSRV/config.yml"}
        temporary=""

        temporary="$(mktemp ${lib.escapeShellArg "${cfg.dataDir}/plugins/DiscordSRV/messages.yml.XXXXXX"})"
        install -m 0640 ${discordSrvMessages} "$temporary"
        mv -f -- "$temporary" ${lib.escapeShellArg "${cfg.dataDir}/plugins/DiscordSRV/messages.yml"}
        temporary=""

        temporary="$(mktemp ${lib.escapeShellArg "${cfg.dataDir}/plugins/DiscordSRV/synchronization.yml.XXXXXX"})"
        install -m 0640 ${discordSrvSynchronization} "$temporary"
        mv -f -- "$temporary" ${lib.escapeShellArg "${cfg.dataDir}/plugins/DiscordSRV/synchronization.yml"}
        temporary=""

        install -d -m 0750 ${lib.escapeShellArg "${cfg.dataDir}/plugins/voicechat"}
        temporary="$(mktemp ${lib.escapeShellArg "${cfg.dataDir}/plugins/voicechat/voicechat-server.properties.XXXXXX"})"
        install -m 0640 ${simpleVoiceChatConfig} "$temporary"
        mv -f -- "$temporary" ${lib.escapeShellArg "${cfg.dataDir}/plugins/voicechat/voicechat-server.properties"}
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
      serviceConfig = {
        WorkingDirectory = cfg.dataDir;
        User = "skyblock";
        Group = "skyblock";
        LoadCredential = [
          "pierdolauth-server-credential:${config.sops.secrets."mine-platform/game-auth-server-credentials".path}"
          "discord-bot-token:${config.sops.secrets."mine-platform/discord-bot-token".path}"
        ];
        RuntimeDirectory = "skyblock-paper";
        RuntimeDirectoryMode = "0700";
        RuntimeDirectoryPreserve = false;
        ExecStart = "${pkgs.jdk25}/bin/java -Xms1G -Xmx2G -Duser.timezone=Europe/Moscow -jar ${cfg.paperJar} --nogui";
        Restart = "always";
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
