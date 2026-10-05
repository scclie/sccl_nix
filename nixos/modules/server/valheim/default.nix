{ config, lib, pkgs, ... }:
let
  cfg = config.sccl.valheim;
  dataDir = cfg.dataDir;
  steamEnv = "${pkgs.steam-run}/bin/steam-run";
  envFile = config.sops.templates."valheim-env".path;
  mods = pkgs.callPackage ./packages.nix { };
  mapHost = "${cfg.webmap.subdomain}.${cfg.webmap.domain}";
  landingHost = "valheim.${cfg.domain}";
  siteHost = config.sccl.server.domain;
  statusUrl = "https://status.${siteHost}/endpoints/${cfg.statusEndpoint}";

  jotunnNeeded = cfg.content.epicLoot || cfg.content.protectiveWards
    || cfg.content.equipmentAndQuickSlots || cfg.content.craftFromChestsPlus
    || cfg.characters.enable;

  conditionalConfigSyncNeeded = cfg.qol.quickStack;

  # the landing page
  landingRoot = pkgs.runCommand "valheim-landing" { } ''
    mkdir -p "$out"
    cp ${./landing.html} "$out/index.html"
    substituteInPlace "$out/index.html" \
      --replace-fail '@@ADDRESS@@' ${lib.escapeShellArg landingHost} \
      --replace-fail '@@GAME_PORT@@' ${lib.escapeShellArg (toString cfg.port)} \
      --replace-fail '@@MAP_URL@@' ${lib.escapeShellArg "https://${mapHost}"} \
      --replace-fail '@@STATUS_URL@@' ${lib.escapeShellArg statusUrl} \
      --replace-fail '@@ACCESS@@' ${lib.escapeShellArg (if packEmpty then "steam only, no crossplay, vanilla clients" else "steam only, no crossplay, modded clients")} \
      ${lib.optionalString (cfg.discordInvite != "") "--replace-fail '@@DISCORD_INVITE@@' ${lib.escapeShellArg cfg.discordInvite}"}${lib.optionalString (cfg.matrixRoom != "") " --replace-fail '@@MATRIX_URL@@' ${lib.escapeShellArg cfg.matrixRoom}"}
    ${lib.optionalString (cfg.webmap.enable == false) "${pkgs.gnused}/bin/sed -i '/<!--map:start-->/,/<!--map:end-->/d' \"$out/index.html\""}
    ${lib.optionalString (cfg.discordInvite == "") "${pkgs.gnused}/bin/sed -i '/<!--discord:start-->/,/<!--discord:end-->/d' \"$out/index.html\""}
    ${lib.optionalString (cfg.matrixRoom == "") "${pkgs.gnused}/bin/sed -i '/<!--matrix:start-->/,/<!--matrix:end-->/d' \"$out/index.html\""}
    ${lib.optionalString (cfg.clientModpack.enable == false) "${pkgs.gnused}/bin/sed -i '/<!--modpack:start-->/,/<!--modpack:end-->/d' \"$out/index.html\""}
    # the markers are build-time scaffolding, not page content
    ${pkgs.gnused}/bin/sed -i '/<!--map:start-->/d; /<!--map:end-->/d; /<!--discord:start-->/d; /<!--discord:end-->/d; /<!--matrix:start-->/d; /<!--matrix:end-->/d; /<!--modpack:start-->/d; /<!--modpack:end-->/d' "$out/index.html"
    # a dropped marker still exits 0, so a surviving @@TOKEN@@ must fail the build
    ! grep -q '@@' "$out/index.html" || {
      echo "valheim-landing: an unsubstituted @@TOKEN@@ survived into the page" >&2
      exit 1
    }
  '';

  modifierArgs = lib.concatMapStringsSep " " (x:
    lib.optionalString (x.value != null) "-modifier ${x.name} ${x.value}")
    [
      {
        name = "Resources";
        value = cfg.worldModifiers.resources;
      }
      {
        name = "Portals";
        value = cfg.worldModifiers.portals;
      }
      {
        name = "DeathPenalty";
        value = cfg.worldModifiers.deathPenalty;
      }
    ];

  # the launch goes through a generated script
  startScript = pkgs.writeShellScript "valheim-start" ''
    exec ${steamEnv} /bin/sh -c '
      # export, not a bare assignment: a shell variable never reaches the game, a child process
      export DOORSTOP_ENABLED=1

      export DOORSTOP_TARGET_ASSEMBLY=${dataDir}/BepInEx/core/BepInEx.Preloader.dll
      export LD_PRELOAD=${mods.bepinex}/doorstop_libs/libdoorstop_x64.so
      export LD_LIBRARY_PATH=${mods.bepinex}/doorstop_libs:${dataDir}/linux64
      export SteamAppId=892970
      export TEMP=/tmp
      export TMPDIR=/tmp
      exec ${dataDir}/valheim_server.x86_64 \
        -name ${lib.escapeShellArg cfg.name} \
        -world ${lib.escapeShellArg cfg.world} \
        -port ${toString cfg.port} \
        -savedir ${lib.escapeShellArg "${dataDir}/savedir"} \
        -password "$VALHEIM_PASSWORD" \
        -public 1 ${modifierArgs}
    '
  '';

  deployScript = import ./deploy.nix {
    inherit pkgs;
    inherit dataDir steamEnv;
    bepinex = mods.bepinex;
    steamcmd = "${pkgs.steamcmd}/bin/steamcmd";
    rcon = mods.rcon;
    rconPort = cfg.rcon.port;
    rconCidrs = lib.concatStringsSep "," cfg.rcon.allowedCidrs;
    discord = mods.discord;
    discordWorldSave = cfg.discord.worldSaveNotifications;
    webmap = mods.webmap;
    webmapPort = cfg.webmap.port;
    webmapHost = mapHost;
    webmapInvite = cfg.discordInvite;
    pwonce = mods.pwonce;
    autosave = mods.autosave;
    jotunn = mods.jotunn;
    jsonDotNet = mods.jsonDotNet;
    yamlDotNet = mods.yamlDotNet;
    reefCharacters = mods.reefCharacters;
    reefOneCharacter = cfg.characters.oneCharacterPerAccount;
    epicLoot = mods.epicLoot;
    plantEverything = mods.plantEverything;
    protectiveWards = mods.protectiveWards;
    wearableTrophies = mods.wearableTrophies;
    equipmentAndQuickSlots = mods.equipmentAndQuickSlots;
    craftFromChestsPlus = mods.craftFromChestsPlus;
    farmGridRemake = mods.farmGridRemake;
    ghettoNetworking = mods.ghettoNetworking;
    quickStackPlus = mods.quickStackPlus;
    conditionalConfigSync = mods.conditionalConfigSync;
    buildCamera = mods.buildCamera;
    speedyPaths = mods.speedyPaths;
    odinHorse = mods.odinHorse;
    odinArchitect = mods.odinArchitect;
    planBuild = mods.planBuild;
  };

  # The client modpack
  packEntries = [
    {
      ts = "denikson-BepInExPack_Valheim-${mods.bepinex.version}";
      on = true;
    }
    {
      ts = "ValheimModding-Jotunn-${mods.jotunn.version}";
      on = jotunnNeeded;
      pkg = mods.jotunn;
    }
    {
      ts = "ValheimModding-JsonDotNET-${mods.jsonDotNet.version}";
      on = cfg.content.epicLoot;
      pkg = mods.jsonDotNet;
    }
    {
      ts = "ValheimModding-YamlDotNet-${mods.yamlDotNet.version}";
      on = cfg.content.protectiveWards;
      pkg = mods.yamlDotNet;
    }
    {
      ts = "nwesterhausen-DiscordConnector-${mods.discord.version}";
      on = cfg.discord.enable;
      pkg = mods.discord;
    }
    {
      ts = "ReefTeam-ReefCharacters-${mods.reefCharacters.version}";
      on = cfg.characters.enable;
      pkg = mods.reefCharacters;
    }
    {
      ts = "RandyKnapp-EpicLoot-${mods.epicLoot.version}";
      on = cfg.content.epicLoot;
      pkg = mods.epicLoot;
    }
    {
      ts = "Advize-PlantEverything-${mods.plantEverything.version}";
      on = cfg.content.plantEverything;
      pkg = mods.plantEverything;
    }
    {
      ts = "shudnal-ProtectiveWards-${mods.protectiveWards.version}";
      on = cfg.content.protectiveWards;
      pkg = mods.protectiveWards;
    }
    {
      ts = "JereKuusela-Wearable_Trophies-${mods.wearableTrophies.version}";
      on = cfg.content.wearableTrophies;
      pkg = mods.wearableTrophies;
    }
    {
      ts = "RandyKnapp-EquipmentAndQuickSlots-${mods.equipmentAndQuickSlots.version}";
      on = cfg.content.equipmentAndQuickSlots;
      pkg = mods.equipmentAndQuickSlots;
    }
    {
      ts = "PONEIS-CraftFromChestsPlus-${mods.craftFromChestsPlus.version}";
      on = cfg.content.craftFromChestsPlus;
      pkg = mods.craftFromChestsPlus;
    }
    {
      ts = "Moopfam-FarmGridRemake-${mods.farmGridRemake.version}";
      on = cfg.content.farmGridRemake;
      pkg = mods.farmGridRemake;
    }
    {
      ts = "ComfyMods-Gizmo-${mods.gizmo.version}";
      on = cfg.content.gizmo;
      pkg = mods.gizmo;
    }
    {
      ts = "shudnal-ConditionalConfigSync-${mods.conditionalConfigSync.version}";
      on = cfg.qol.quickStack;
      pkg = mods.conditionalConfigSync;
    }
    {
      ts = "Goneryx-QuickStackPlus-${mods.quickStackPlus.version}";
      on = cfg.qol.quickStack;
      pkg = mods.quickStackPlus;
    }
    {
      ts = "Azumatt-AzuClock-${mods.azuClock.version}";
      on = cfg.ui.azuClock;
      pkg = mods.azuClock;
    }
    {
      ts = "Azumatt-Build_Camera_Custom_Hammers_Edition-${mods.buildCamera.version}";
      on = cfg.ui.buildCamera;
      pkg = mods.buildCamera;
    }
    {
      ts = "ComfyMods-ComfyLadders-${mods.comfyLadders.version}";
      on = cfg.ui.comfyLadders;
      pkg = mods.comfyLadders;
    }
    {
      ts = "Searica-AdvancedTerrainModifiers-${mods.advancedTerrainModifiers.version}";
      on = cfg.ui.terrainer;
      pkg = mods.advancedTerrainModifiers;
    }
    {
      ts = "BasilPanda-NoStamCosts-${mods.noStamCosts.version}";
      on = cfg.qol.noStamCosts;
      pkg = mods.noStamCosts;
    }
    {
      ts = "cjayride-ConfigurationManager-${mods.configurationManager.version}";
      on = cfg.ui.configurationManager;
      pkg = mods.configurationManager;
    }
    {
      ts = "MathiasDecrock-PlanBuild-${mods.planBuild.version}";
      on = cfg.content.planBuild;
      pkg = mods.planBuild;
    }
    {
      ts = "OdinPlus-OdinArchitect-${mods.odinArchitect.version}";
      on = cfg.content.odinArchitect;
      pkg = mods.odinArchitect;
    }
    {
      ts = "OdinPlus-OdinHorse-${mods.odinHorse.version}";
      on = cfg.content.odinHorse;
      pkg = mods.odinHorse;
    }
    {
      ts = "Nextek-SpeedyPaths-${mods.speedyPaths.version}";
      on = cfg.qol.speedyPaths;
      pkg = mods.speedyPaths;
    }
    {
      ts = "VerdantsAscent-FiresGhettoNetworking-${mods.ghettoNetworking.version}";
      on = cfg.networking.enable;
      pkg = mods.ghettoNetworking;
    }
  ];

  packDeps = map (entry: entry.ts) packEntries;
  packEmpty = packDeps == [ "denikson-BepInExPack_Valheim-${mods.bepinex.version}" ];

  packFiles = lib.concatMap
    (entry: lib.optional entry.on {
      dir = lib.removeSuffix "-${entry.pkg.version}" entry.ts;
      pkg = entry.pkg;
    })
    (lib.filter (entry: entry ? pkg) packEntries);

  packManifest = pkgs.writeText "manifest.json" (builtins.toJSON {
    name = "${cfg.name}-modpack";
    version_number = cfg.clientModpack.version;
    website_url = "https://${landingHost}";
    description = "Mods for the ${cfg.name} server, pinned to the versions it runs";
    dependencies = packDeps;
  });

  packLauncher = pkgs.writeText "start_game_bepinex.sh" ''
    #!/bin/sh
    # BepInEx launcher for the native Linux build.
    #
    # Native Linux and macOS builds import no winhttp.dll, so Doorstop can only be reached
    # through LD_PRELOAD. Windows players need none of this: the game loads winhttp.dll
    # itself and never runs this script.
    set -e

    # Script directory from $0 alone: cd and pwd are shell builtins, so this works even
    # when Steam hands us a PATH without coreutils, which is the whole reason the upstream
    # script and its dirname call are not used here.
    dir=''${0%/*}
    [ "$dir" = "$0" ] && dir=.
    dir=$(CDPATH= cd -- "$dir" && pwd)

    # Steam's launch options hand us the whole command line, so an explicit executable in
    # first position is ours to drop, not the game's to choke on. Pure shell, no basename.
    case "''${1:-}" in
      */valheim.x86_64) shift ;;
    esac

    export DOORSTOP_ENABLED=1
    export DOORSTOP_TARGET_ASSEMBLY="$dir/BepInEx/core/BepInEx.Preloader.dll"
    export LD_LIBRARY_PATH="$dir/doorstop_libs''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
    export LD_PRELOAD="$dir/doorstop_libs/libdoorstop_x64.so''${LD_PRELOAD:+:$LD_PRELOAD}"

    exec "$dir/valheim.x86_64" "$@"
  '';

  packReadme = pkgs.writeText "README-draumur.txt" ''
    ## ? моды

    модпак автоматом собирается из тех же версий, что крутятся на сервере, ссылка на лендинге.
    распаковать в корень игры.

    **linux:**
    `~/.local/share/Steam/steamapps/common/Valheim/`
    нативный билд не подхватывает `winhttp.dll`, поэтому запускать через `./start_game_bepinex.sh`,
    в steam: параметры запуска:
    `~/.local/share/Steam/steamapps/common/Valheim/start_game_bepinex.sh %command%`

    **windows:**
    `C:\Program Files (x86)\Steam\steamapps\common\Valheim\`
    запускать как обычно, `winhttp.dll` подхватится сам.

    **uninstall:**
    удалить `BepInEx`, `winhttp.dll`, `doorstop_config.ini`, `doorstop_libs`,
    `.doorstop_version`, `start_game_bepinex.sh`.
  '';

  clientPack = pkgs.runCommand "${cfg.name}-modpack.zip" { nativeBuildInputs = [ pkgs.zip ]; } ''
    mkdir -p unpack/BepInEx/plugins
    cp ${packManifest} unpack/manifest.json
    cp ${packReadme} unpack/README.txt
    cp -r ${mods.bepinex}/BepInEx/core unpack/BepInEx/core
    mkdir -p unpack/BepInEx/config
    cp ${mods.bepinex}/BepInEx/config/BepInEx.cfg unpack/BepInEx/config/BepInEx.cfg
    cp -r ${mods.bepinex}/doorstop_libs unpack/doorstop_libs
    cp ${mods.bepinex}/winhttp.dll unpack/winhttp.dll
    cp ${mods.bepinex}/doorstop_config.ini unpack/doorstop_config.ini
    cp ${mods.bepinex}/.doorstop_version unpack/.doorstop_version
    # our launcher, not ${mods.bepinex}/start_game_bepinex.sh: see packLauncher
    install -m 0755 ${packLauncher} unpack/start_game_bepinex.sh
    ${lib.concatMapStringsSep "\n    " (entry: ''
      mkdir -p unpack/BepInEx/plugins/${lib.escapeShellArg entry.dir}
      cp -r ${entry.pkg}/plugins/* unpack/BepInEx/plugins/${lib.escapeShellArg entry.dir}/
    '') packFiles}
    chmod -R u+rwX unpack
    cd unpack
    ${pkgs.zip}/bin/zip -q -9 -r "$out" .
  '';
in {
  options.sccl.valheim = {
    enable = lib.mkEnableOption "Valheim dedicated server (steamcmd install)";

    domain = lib.mkOption {
      type = lib.types.str;
      default = "pierdol.ing";
      description = "Public domain for the landing page; the vhost is valheim.<domain> and the wildcard cert is read from it. Deliberately separate from webmap.domain, which names the map only";
    };

    dataDir = lib.mkOption {
      type = lib.types.str;
      default = "/tank/valheim";
      description = "Working directory of the server: game files, savedir, BepInEx, plugins. Backed by the data/valheim ZFS dataset in disko.nix. The dataset must be created by hand before the first switch, because disko manages datasets and does not migrate data into one it creates; a systemd.tmpfiles rule creates this path with the right ownership as a safety net";
    };

    name = lib.mkOption {
      type = lib.types.str;
      default = "laeradr";
      description = "Server name shown in the Steam community list";
    };

    discordInvite = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = "Public Discord invite linked from the landing page; empty drops the link. Not a secret. It was previously webmap.discordInvite, but WebMap 2.9.0 binds discord_invite_url from its config and then never surfaces it - MakeClientConfigJson() omits it and neither wm.cs nor mds.cs reads it - so this page is the only consumer";
    };

    matrixRoom = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = "Matrix room linked from the landing page, full matrix.to URL; empty drops the link";
    };

    statusEndpoint = lib.mkOption {
      type = lib.types.str;
      default = "games_valheim";
      description = "Gatus endpoint name linked as [ status ]. The URL is built as https://status.<sccl.server.domain>/endpoints/<this>, so it must match the endpoint name declared under status.endpoints exactly - Gatus derives the path from the name";
    };

    world = lib.mkOption {
      type = lib.types.str;
      default = "Midgard";
      description = "World name";
    };

    # Vanilla world modifiers
    worldModifiers = {
      resources = lib.mkOption {
        type = lib.types.nullOr (lib.types.enum [
          "muchless"
          "less"
          "more"
          "muchmore"
          "most"
        ]);
        default = null;
        description = "Resource rate: muchless 0.5x, less 0.75x, more 1.5x, muchmore 2x, most 3x. Does not affect fish, trophies or boss drops";
      };

      portals = lib.mkOption {
        type = lib.types.nullOr (lib.types.enum [
          "casual"
          "hard"
          "veryhard"
        ]);
        default = null;
        description = "casual lets ores and metals travel through portals (TeleportAll), hard is the vanilla default and keeps them out, veryhard bans portals entirely";
      };

      deathPenalty = lib.mkOption {
        type = lib.types.nullOr (lib.types.enum [
          "casual"
          "veryeasy"
          "easy"
          "hard"
          "hardcore"
        ]);
        default = null;
        description = "casual keeps equipped gear on the player and drops the rest, with 1% skill loss instead of 5%. hard and hardcore destroy items outright, hardcore deletes the character";
      };
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 2456;
      description = "Game port; Valheim also binds port+1";
    };

    rcon = {
      enable = lib.mkEnableOption "Tristan-ValheimRcon moderation console (LAN/VPN only)";
      port = lib.mkOption {
        type = lib.types.port;
        default = cfg.port + 2;
        description = "TCP port for the RCON console; reachable from the whole host firewall, kept off the internet by the router not forwarding it";
      };
      allowedCidrs = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [
          "192.168.0.0/24"
          "${config.sccl.wireguard.subnet}.0/24"
        ];
        description = "CIDRs permitted to use RCON; every other source is dropped by the mod itself, not by the host firewall";
      };
    };

    discord = {
      enable = lib.mkEnableOption "nwesterhausen DiscordConnector (server lifecycle and player events)";

      worldSaveNotifications = lib.mkEnableOption "Discord notifications on every world save. Off by default: the mod posts one message per save, and qol.autoSaveInterval alone saves the world every 10 minutes, so the channel would see six an hour of \"The world has been saved\"";
    };

    webmap = {
      enable = lib.mkEnableOption "f00d4tehg0dz Valheim WebMap";
      port = lib.mkOption {
        type = lib.types.port;
        default = 3002;
        description = "HTTP port for the map. 3000 is taken twice over: comments.nix:98 and forgejo/default.nix:226 both open it, so 3002 it is";
      };
      domain = lib.mkOption {
        type = lib.types.str;
        default = "pierdol.ing";
        description = "Public domain serving the map; read for the map vhost name together with subdomain";
      };
      subdomain = lib.mkOption {
        type = lib.types.str;
        default = "map-valheim";
        description = "Subdomain serving the map; the map vhost is <subdomain>.<domain>";
      };
    };

    qol = {
      passwordOnce = lib.mkEnableOption "DooDesch ServerPasswordOnce (returning players are asked for the password once, not every join)";
      autoSaveInterval = lib.mkEnableOption "Baka_Gaijin AutoSaveInterval (periodic world save, 10 minutes by default)";
      speedyPaths = lib.mkEnableOption "Nextek SpeedyPaths: paths and constructions give a speed bonus and cheaper sprinting, stone 1.4x and dirt 1.15x. Server side so its config sync is authoritative";
      quickStack = lib.mkEnableOption "Goneryx QuickStackPlus: quick stack into nearby containers, per-container smart storage, on-demand sorting and a trash mark-and-delete. Server side so the master switch and search radius stay admin controlled, which is what it syncs through ConditionalConfigSync";
      noStamCosts = lib.mkEnableOption "BasilPanda NoStamCosts: hammer, hoe and cultivator cost no stamina, the rest is in Basil_NoStamCosts.cfg where 3 makes everything free. Client side only, it zeroes the value before the stamina RPC, so the server never sees a cost either";
    };

    # Every mod in here needs BepInEx and installed on client/server
    content = {
      epicLoot = lib.mkEnableOption "RandyKnapp EpicLoot: magic through ancient loot, item effects, shard slots, tempering. The largest gameplay change in the pack";
      plantEverything = lib.mkEnableOption "Advize PlantEverything: cultivator recipes and crops outside their vanilla biome and terrain restrictions";
      protectiveWards = lib.mkEnableOption "shudnal ProtectiveWards: base access control, guilds, and ten active offerings that are all on by default. Existing wards survive an upgrade";
      wearableTrophies = lib.mkEnableOption "JereKuusela Wearable_Trophies: trophies and gear worn for looks only";
      equipmentAndQuickSlots = lib.mkEnableOption "RandyKnapp EquipmentAndQuickSlots: armour slots and six quick slots. Never downgrade to 2.x after a character has saved under 3.x";
      craftFromChestsPlus = lib.mkEnableOption "PONEIS CraftFromChestsPlus: craft, build and smelt from chests near a placed totem";
      farmGridRemake = lib.mkEnableOption "Moopfam FarmGridRemake: cultivator planting snaps to a grid around the nearest plant, and growth restrictions can be lifted. The grid is client side, the lifted restrictions are not, so the server runs it too";
      gizmo = lib.mkEnableOption "ComfyMods ComfyGizmo: building rotation hotkeys and snap angles. Client side only, it is in the modpack and never on the server";
      odinArchitect = lib.mkEnableOption "OdinPlus OdinArchitect: 200+ building pieces with elevators, drawbridges, hatches and automated smelters. Adds pieces and recipes, so the server runs it too";
      odinHorse = lib.mkEnableOption "OdinPlus OdinHorse: tameable rideable horse that breeds, carries saddlebags, pulls the horse cart and fights alongside you in the saddle. Adds a creature and items, so the server runs it too";
      planBuild = lib.mkEnableOption "MathiasDecrock PlanBuild: the plan hammer plans pieces before you gather the materials, the blueprint rune copies, saves and shares builds, plus its own terrain and object tools. Adds items and recipes, so the server runs it too. Its terrain tools overlap Searica AdvancedTerrainModifiers, watch the log after the first start";
    };

    # HUD, camera, navigation
    ui = {
      azuClock = lib.mkEnableOption "Azumatt AzuClock: HUD clock with day number, biome, weather and a forecast. Deprecated upstream";
      comfyLadders = lib.mkEnableOption "ComfyMods ComfyLadders: ladders auto-jumpable, the maintained BetterLadders";
      buildCamera = lib.mkEnableOption "Azumatt Build Camera Custom Hammers Edition: detaches the camera from the player while building. Deprecated upstream";
      terrainer = lib.mkEnableOption "Searica AdvancedTerrainModifiers: radius, sharpness and square variants for the hoe and cultivator, plus a shovel and a precision raise tool. Client side only, terrain changes sync through the vanilla system";
      configurationManager = lib.mkEnableOption "cjayride ConfigurationManager: GUI for editing BepInEx configs in game, so NoStamCosts, Searica and the rest do not need a restart. Client side only, server-synced settings stay admin only";
    };

    characters = {
      enable = lib.mkEnableOption "ReefTeam ReefCharacters: character profiles live in the server's characters_local/, so a character created on another server cannot be brought in";

      oneCharacterPerAccount = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Whether a Steam account that already has a character here may not log in with another one. This is the mod's own default and it is only documented in its readme, so the deploy writes it explicitly; admins in savedir/adminlist.txt are exempt either way";
      };
    };

    networking = {
      enable = lib.mkEnableOption "VerdantsAscent FiresGhettoNetworking: transport and traffic tuning for a busy server. Its Server-Side Simulation and ZDO ownership transfer switches are left off, and the standalone server-side simulation mods are not installed, its README forbids stacking networking mods";
    };

    clientModpack = {
      enable = lib.mkEnableOption "Build the Thunderstore package players install and serve it from the landing page at /mods.zip";

      version = lib.mkOption {
        type = lib.types.str;
        default = "1.0.0";
        description = "version_number of the modpack. Bump it whenever a dependency changes, or a mod manager sees the pack it already has and installs nothing";
      };
    };

    config.assertions = [
      {
        assertion = cfg.port <= 65533;
        message = "sccl.valheim.port must leave room for port+1 and rcon.port (port+2).";
      }
    ];
  };

  config = lib.mkIf cfg.enable {
    systemd.tmpfiles.rules = [ "d ${dataDir} 0755 valheim valheim -" ];

    users.users.valheim = {
      isSystemUser = true;
      group = "valheim";
      home = dataDir;
      description = "Valheim dedicated server";
    };
    users.groups.valheim = { };

    sops.secrets."valheim/server-password" = {
      sopsFile = ../../../../secrets/apps.yaml;
    };
    sops.secrets."valheim/discord-webhook" = {
      sopsFile = ../../../../secrets/apps.yaml;
    };
    sops.secrets."valheim/rcon-password" = {
      sopsFile = ../../../../secrets/apps.yaml;
    };

    sops.templates."valheim-env" = {
      content = ''
        VALHEIM_PASSWORD=${config.sops.placeholder."valheim/server-password"}
        VALHEIM_DISCORD_WEBHOOK=${config.sops.placeholder."valheim/discord-webhook"}
        VALHEIM_RCON_PASSWORD=${config.sops.placeholder."valheim/rcon-password"}
      '';
      path = "/etc/nixos/secrets/valheim.env";
      mode = "0400";
      owner = "valheim";
    };

    systemd.services.valheim-deploy = {
      description = "Install Valheim and lay out the BepInEx tree";
      after = [ "sops-install-secrets.service" ];
      wants = [ "sops-install-secrets.service" ];
      wantedBy = [ "valheim.service" ];
      serviceConfig = {
        Type = "oneshot";
        User = "valheim";
        Group = "valheim";
        EnvironmentFile = envFile;
        Environment = lib.concatStringsSep " " (lib.filter (s: s != "") [
          (lib.optionalString cfg.rcon.enable "VALHEIM_RCON_ENABLE=1")
          (lib.optionalString cfg.discord.enable "VALHEIM_DISCORD_ENABLE=1")
          (lib.optionalString cfg.webmap.enable "VALHEIM_WEBMAP_ENABLE=1")
          (lib.optionalString cfg.qol.passwordOnce "VALHEIM_QOL_PWONCE=1")
          (lib.optionalString cfg.qol.autoSaveInterval "VALHEIM_QOL_AUTOSAVE=1")
          (lib.optionalString jotunnNeeded "VALHEIM_JOTUNN_ENABLE=1")
          (lib.optionalString cfg.content.epicLoot "VALHEIM_JSONDOTNET_ENABLE=1 VALHEIM_EPICLOOT_ENABLE=1")
          (lib.optionalString cfg.content.protectiveWards "VALHEIM_YAMLDOTNET_ENABLE=1 VALHEIM_PROTECTIVE_WARDS_ENABLE=1")
          (lib.optionalString cfg.content.plantEverything "VALHEIM_PLANT_EVERYTHING_ENABLE=1")
          (lib.optionalString cfg.content.wearableTrophies "VALHEIM_WEARABLE_TROPHIES_ENABLE=1")
          (lib.optionalString cfg.content.equipmentAndQuickSlots "VALHEIM_EQS_ENABLE=1")
          (lib.optionalString cfg.content.craftFromChestsPlus "VALHEIM_CRAFT_CHESTS_ENABLE=1")
          (lib.optionalString cfg.content.farmGridRemake "VALHEIM_FARM_GRID_ENABLE=1")
          (lib.optionalString cfg.characters.enable "VALHEIM_REEF_ENABLE=1")
          (lib.optionalString cfg.networking.enable "VALHEIM_NETWORKING_ENABLE=1")
          (lib.optionalString conditionalConfigSyncNeeded "VALHEIM_CONDITIONAL_CONFIG_SYNC_ENABLE=1")
          (lib.optionalString cfg.qol.quickStack "VALHEIM_QUICKSTACK_ENABLE=1")
          (lib.optionalString cfg.ui.buildCamera "VALHEIM_BUILD_CAMERA_ENABLE=1")
          (lib.optionalString cfg.qol.speedyPaths "VALHEIM_SPEEDY_PATHS_ENABLE=1")
          (lib.optionalString cfg.content.odinHorse "VALHEIM_ODIN_HORSE_ENABLE=1")
          (lib.optionalString cfg.content.odinArchitect "VALHEIM_ODIN_ARCHITECT_ENABLE=1")
          (lib.optionalString cfg.content.planBuild "VALHEIM_PLAN_BUILD_ENABLE=1")
        ]);
      };
      script = "${deployScript}/bin/valheim-deploy";
    };

    systemd.services.valheim = {
      description = "Valheim dedicated server";
      after = [
        "network-online.target"
        "sops-install-secrets.service"
        "valheim-deploy.service"
      ];
      wants = [
        "network-online.target"
        "sops-install-secrets.service"
        "valheim-deploy.service"
      ];
      wantedBy = [ "multi-user.target" ];
      restartTriggers = [ "" ];

      serviceConfig = {
        Type = "simple";
        User = "valheim";
        Group = "valheim";
        WorkingDirectory = dataDir;
        EnvironmentFile = envFile;
        ExecStart = "${startScript}";
        Restart = "on-failure";
        RestartSec = "10s";
        # valheim sometimes dies with SIGSEGV on shutdown, do not treat that as failure
        SuccessExitStatus = [ 143 ];
      };
    };

    networking.firewall.allowedUDPPorts = [ cfg.port (cfg.port + 1) ];

    # the RCON port (2458 by default) is TCP and must reach the LAN and the WireGuard
    networking.firewall.allowedTCPPorts = lib.mkIf cfg.rcon.enable [ cfg.rcon.port ];

    # the WebMap port stays closed here: plain HTTP carrying every player's live
    services.nginx.virtualHosts = {
      # one location covers page and WebSocket, the mod serves both on one port and the page
      # upgrades to wss from location.href. ${mapHost} is quoted, else it is the attribute name
      "${mapHost}" = lib.mkIf cfg.webmap.enable {
        forceSSL = true;
        enableACME = false;
        sslCertificate = "/var/lib/acme/wildcard.${cfg.webmap.domain}/fullchain.pem";
        sslCertificateKey = "/var/lib/acme/wildcard.${cfg.webmap.domain}/key.pem";

        locations."/" = {
          proxyPass = "http://127.0.0.1:${toString cfg.webmap.port}";
          proxyWebsockets = true;
          # recommendedProxySettings is off
          recommendedProxySettings = false;
          # no Cache-Control of our own: WebMap already stamps "public, max-age=604800, immutable" on its assets, and overriding that breaks the contract
          extraConfig = ''
            proxy_set_header Host ${mapHost};
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            proxy_set_header X-Forwarded-Host ${mapHost};
            proxy_set_header X-Forwarded-Server $hostname;
            proxy_read_timeout 3600s;
          '';
        };
      };

      "${landingHost}" = {
        # forceSSL, not addSSL: a plaintext copy of a public page buys nothing and costs a 301
        forceSSL = true;
        sslCertificate = "/var/lib/acme/wildcard.${cfg.domain}/fullchain.pem";
        sslCertificateKey = "/var/lib/acme/wildcard.${cfg.domain}/key.pem";

        locations."/" = {
          root = landingRoot;
          index = "index.html";
        };

        locations."= /mods.zip" = lib.mkIf cfg.clientModpack.enable {
          # clientPack is the zip itself, not a directory holding one
          alias = "${clientPack}";
          extraConfig = ''
            default_type application/zip;
            add_header Content-Disposition 'attachment; filename="${cfg.name}-modpack.zip"';
          '';
        };
      };
    };
  };
}
