{ pkgs, dataDir, bepinex, steamEnv, steamcmd, rcon, rconPort, rconCidrs, discord, discordWorldSave, webmap, webmapPort, webmapHost, webmapInvite, pwonce, autosave, jotunn, jsonDotNet, yamlDotNet, reefCharacters, reefOneCharacter, epicLoot, plantEverything, protectiveWards, wearableTrophies, equipmentAndQuickSlots, craftFromChestsPlus, farmGridRemake, ghettoNetworking, quickStackPlus, conditionalConfigSync, buildCamera, speedyPaths, odinHorse, odinArchitect }:

pkgs.writeShellApplication {
  name = "valheim-deploy";
  runtimeInputs = [ pkgs.coreutils ];
  text = ''
    set -euo pipefail

    DATA_DIR=${dataDir}
    BEPINEX=${bepinex}
    STEAMCMD=${steamcmd}
    STEAM_RUN=${steamEnv}

    # idempotent symlink: replaces a stale symlink, refuses to overwrite a real file or directory so a manual install is never silently destroyed.
    link_path() {
      local src=$1
      local dst=$2
      if [ ! -e "$src" ]; then
        echo "valheim-deploy: source $src does not exist" >&2
        exit 1
      fi
      if [ -L "$dst" ] && [ "$(readlink "$dst")" = "$src" ]; then
        return 0
      fi
      if [ -e "$dst" ] && [ ! -L "$dst" ]; then
        echo "valheim-deploy: $dst exists as a real file or directory; move it aside and re-run" >&2
        exit 1
      fi
      rm -f "$dst"
      ln -s "$src" "$dst"
      echo "valheim-deploy: linked $dst -> $src"
    }

    copy_asset() {
      local src=$1
      local dst=$2
      if [ ! -e "$src" ]; then
        echo "valheim-deploy: source $src does not exist" >&2
        exit 1
      fi
      if [ -f "$dst" ] && [ ! -L "$dst" ] && cmp -s "$src" "$dst"; then
        return 0
      fi
      rm -f "$dst"
      cp "$src" "$dst"
      chmod 0644 "$dst"
      echo "valheim-deploy: copied $dst as a real file (must not be a symlink)"
    }

    # mod <0|1> <package> <entry>...
    mod() {
      local enabled=$1
      local src=$2
      shift 2
      local dst="$DATA_DIR/BepInEx/plugins"
      local f
      mkdir -p "$dst"
      if [ "$enabled" = "1" ]; then
        if [ ! -d "$src/plugins" ]; then
          echo "valheim-deploy: $src/plugins does not exist" >&2
          exit 1
        fi
        for f in "$src"/plugins/*; do
          link_path "$f" "$dst/$(basename "$f")"
        done
      else
        for f in "$@"; do
          if [ -L "$dst/$f" ]; then
            rm -f "$dst/$f"
            echo "valheim-deploy: unlinked $dst/$f"
          fi
        done
      fi
    }

    # writes a config value bare
    check_bare() {
      local name=$1
      local val=$2
      case "$val" in
        *[[:space:]\"\\\#]*)
          echo "valheim-deploy: refusing to write config value for '$name':" >&2
          echo "  a bare TOML value cannot contain whitespace, a quote, a backslash or #" >&2
          echo "  and this BepInEx build does not strip quotes, so quoting breaks it." >&2
          echo "  value was: $val" >&2
          exit 1
          ;;
      esac
    }

    mkdir -p "$DATA_DIR/BepInEx/config" "$DATA_DIR/BepInEx/patchers" "$DATA_DIR/BepInEx/cache" "$DATA_DIR/BepInEx/plugins"
    mkdir -p "$DATA_DIR/savedir"

    # game install/update
    $STEAM_RUN $STEAMCMD \
      +@sSteamCmdForcePlatformType linux \
      +force_install_dir "$DATA_DIR" \
      +login anonymous \
      +app_update 896660 \
      +quit || echo "valheim-deploy: steamcmd update failed, reusing the existing installation"

    # valheim needs steamclient.so via ~/.steam/sdk64
    mkdir -p "$DATA_DIR/.steam/sdk64"
    ln -sf "$DATA_DIR/.local/share/Steam/linux64/steamclient.so" "$DATA_DIR/.steam/sdk64/steamclient.so"
    test -x "$DATA_DIR/valheim_server.x86_64"

    link_path "$BEPINEX/doorstop_config.ini" "$DATA_DIR/doorstop_config.ini"
    link_path "$BEPINEX/winhttp.dll" "$DATA_DIR/winhttp.dll"
    link_path "$BEPINEX/doorstop_libs" "$DATA_DIR/doorstop_libs"
    link_path "$BEPINEX/BepInEx/core" "$DATA_DIR/BepInEx/core"

    echo "valheim-deploy: BepInEx core -> $BEPINEX/BepInEx/core"

    mod "''${VALHEIM_RCON_ENABLE:-0}" ${rcon} ValheimRcon.dll
    if [ "''${VALHEIM_RCON_ENABLE:-0}" = "1" ]; then
      # names and values are bare, which this BepInEx build round-trips itself even
      # though the section "1. Rcon" and key "Whitelist IP mask" hold spaces and a dot.
      rcon_pw=$VALHEIM_RCON_PASSWORD
      check_bare "Password" "$rcon_pw"
      check_bare "Whitelist IP mask" "${rconCidrs}"
      printf '%s\n' \
        '[1. Rcon]' \
        "Port = ${toString rconPort}" \
        "Password = $rcon_pw" \
        "Whitelist IP mask = ${rconCidrs}" \
        > "$DATA_DIR/BepInEx/config/org.tristan.rcon.cfg"
      # umask 077 only bites at creation and the mod rewrites this file, so chmod it.
      chmod 0600 "$DATA_DIR/BepInEx/config/org.tristan.rcon.cfg"
    else
      rm -f "$DATA_DIR/BepInEx/config/org.tristan.rcon.cfg"
    fi

    mod "''${VALHEIM_DISCORD_ENABLE:-0}" ${discord} DiscordConnector.dll
    if [ "''${VALHEIM_DISCORD_ENABLE:-0}" = "1" ]; then
      DC_CFG="$DATA_DIR/BepInEx/config/games.nwest.valheim.discordconnector"
      (
        umask 077
        mkdir -p "$DC_CFG"
        webhook="''${VALHEIM_DISCORD_WEBHOOK:-}"
        if [ -z "$webhook" ]; then
          echo "valheim-deploy: VALHEIM_DISCORD_WEBHOOK is empty" >&2
          exit 1
        fi
        case "$webhook" in
          *[\"\\$'\n'$'\r']*)
            echo "valheim-deploy: VALHEIM_DISCORD_WEBHOOK contains a quote, backslash or control character; refusing to write a config Tomlyn would reject" >&2
            exit 1
            ;;
        esac

        check_bare "Webhook URL" "$webhook"
        printf '%s\n' \
          '[Main Settings]' \
          "Webhook URL = $webhook" \
          > "$DC_CFG/discordconnector.cfg"

        printf '%s\n' \
          '[Toggles.Messages]' \
          "Server World Save Notifications = ${if discordWorldSave then "true" else "false"}" \
          > "$DC_CFG/discordconnector-toggles.cfg"
        chmod 0600 "$DC_CFG/discordconnector.cfg"

        chmod 0600 "$DC_CFG/discordconnector-toggles.cfg"

        chmod 0700 "$DC_CFG"
      )
    else
      rm -rf "$DATA_DIR/BepInEx/config/games.nwest.valheim.discordconnector"
    fi

    rm -f "$DATA_DIR/BepInEx/config/com.github.h0tw1r3.valheim.webmap.cfg"
    rm -f "$DATA_DIR/BepInEx/plugins/WebMap.dll"
    rm -rf "$DATA_DIR/BepInEx/plugins/web"
    rm -rf "$DATA_DIR/BepInEx/plugins/map_data"

    if [ "''${VALHEIM_WEBMAP_ENABLE:-0}" = "1" ]; then
      mkdir -p "$DATA_DIR/BepInEx/plugins/WebMap/map_data"
      copy_asset "${webmap}/WebMap/WebMap.dll" "$DATA_DIR/BepInEx/plugins/WebMap/WebMap.dll"
      link_path "${webmap}/WebMap/websocket-sharp.dll" "$DATA_DIR/BepInEx/plugins/WebMap/websocket-sharp.dll"
      link_path "${webmap}/WebMap/web" "$DATA_DIR/BepInEx/plugins/WebMap/web"

      (
        umask 077
        check_bare "webmap_url" "https://${webmapHost}"
        check_bare "discord_invite_url" "${webmapInvite}"
        printf '%s\n' \
          '[Server]' \
          "server_port = ${toString webmapPort}" \
          "webmap_url = https://${webmapHost}" \
          "discord_invite_url = ${webmapInvite}" \
          > "$DATA_DIR/BepInEx/config/com.valheimwebmap.server.cfg"

        chmod 0600 "$DATA_DIR/BepInEx/config/com.valheimwebmap.server.cfg"
      )
    else

      rm -f "$DATA_DIR/BepInEx/config/com.valheimwebmap.server.cfg"
      rm -rf "$DATA_DIR/BepInEx/plugins/WebMap"
    fi

    mod "''${VALHEIM_QOL_PWONCE:-0}" ${pwonce} ServerPasswordOnce.dll
    mod "''${VALHEIM_QOL_AUTOSAVE:-0}" ${autosave} AutoSaveInterval.dll

    mod "''${VALHEIM_JOTUNN_ENABLE:-0}" ${jotunn} Jotunn
    mod "''${VALHEIM_JSONDOTNET_ENABLE:-0}" ${jsonDotNet} Newtonsoft.Json.dll NewtonsoftJsonDetector.dll
    mod "''${VALHEIM_YAMLDOTNET_ENABLE:-0}" ${yamlDotNet} YamlDotNet.dll YamlDotNetDetector.dll

    mod "''${VALHEIM_REEF_ENABLE:-0}" ${reefCharacters} ReefCharacters.dll
    if [ "''${VALHEIM_REEF_ENABLE:-0}" = "1" ]; then
      (
        umask 077
        printf '%s\n' \
          '[Server]' \
          'Backups to keep = 25' \
          'One character per account = ${if reefOneCharacter then "true" else "false"}' \
          > "$DATA_DIR/BepInEx/config/reef.characters.cfg"
        chmod 0600 "$DATA_DIR/BepInEx/config/reef.characters.cfg"
      )
    else
      rm -f "$DATA_DIR/BepInEx/config/reef.characters.cfg"
    fi

    mod "''${VALHEIM_EPICLOOT_ENABLE:-0}" ${epicLoot} EpicLoot

    mod "''${VALHEIM_PLANT_EVERYTHING_ENABLE:-0}" ${plantEverything} Advize_PlantEverything.dll

    mod "''${VALHEIM_PROTECTIVE_WARDS_ENABLE:-0}" ${protectiveWards} ProtectiveWards.dll

    mod "''${VALHEIM_WEARABLE_TROPHIES_ENABLE:-0}" ${wearableTrophies} WearableTrophies.dll

    mod "''${VALHEIM_EQS_ENABLE:-0}" ${equipmentAndQuickSlots} EquipmentAndQuickSlots.dll

    mod "''${VALHEIM_CRAFT_CHESTS_ENABLE:-0}" ${craftFromChestsPlus} CraftFromChestsPlus.dll
    mod "''${VALHEIM_FARM_GRID_ENABLE:-0}" ${farmGridRemake} FarmGridRemake.dll
    mod "''${VALHEIM_ODIN_HORSE_ENABLE:-0}" ${odinHorse} OdinHorse.dll
    # OdinArchitect loads its localisation json from a folder next to the dll, so the whole
    # directory has to land in plugins/ and not just the assembly.
    mod "''${VALHEIM_ODIN_ARCHITECT_ENABLE:-0}" ${odinArchitect} OdinArchitect

    mod "''${VALHEIM_NETWORKING_ENABLE:-0}" ${ghettoNetworking} VAGhettoNetworking.dll

    mod "''${VALHEIM_CONDITIONAL_CONFIG_SYNC_ENABLE:-0}" ${conditionalConfigSync} \
      ConditionalConfigSync.dll ConditionalConfigSync.Plugin.dll
    mod "''${VALHEIM_QUICKSTACK_ENABLE:-0}" ${quickStackPlus} QuickStackPlus.dll
    mod "''${VALHEIM_BUILD_CAMERA_ENABLE:-0}" ${buildCamera} "Build Camera.dll"
    mod "''${VALHEIM_SPEEDY_PATHS_ENABLE:-0}" ${speedyPaths} SpeedyPaths.dll
  '';
}
