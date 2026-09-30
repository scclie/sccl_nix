{ pkgs, dataDir, bepinex, steamEnv, steamcmd, rcon, rconPort, rconCidrs, discord, webmap, webmapPort, webmapHost, webmapInvite, pwonce, autosave }:

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
      # check the source too: a wrong store path is invisible here and ln -s would
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

    if [ "''${VALHEIM_RCON_ENABLE:-0}" = "1" ]; then
      link_path "${rcon}/plugins/ValheimRcon.dll" "$DATA_DIR/BepInEx/plugins/ValheimRcon.dll"
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
    fi

    if [ "''${VALHEIM_DISCORD_ENABLE:-0}" = "1" ]; then
      link_path "${discord}/plugins/DiscordConnector.dll" "$DATA_DIR/BepInEx/plugins/DiscordConnector.dll"
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
        chmod 0600 "$DC_CFG/discordconnector.cfg"
        # the directory needs 0700: the mod writes config-dump.json there with the
        # webhook in cleartext at the default 0644.
        chmod 0700 "$DC_CFG"
      )
    fi

    if [ "''${VALHEIM_WEBMAP_ENABLE:-0}" = "1" ]; then
      rm -f "$DATA_DIR/BepInEx/config/com.github.h0tw1r3.valheim.webmap.cfg"
      rm -f "$DATA_DIR/BepInEx/plugins/WebMap.dll"
      rm -f "$DATA_DIR/BepInEx/plugins/websocket-sharp.dll"
      rm -rf "$DATA_DIR/BepInEx/plugins/web"
      rm -rf "$DATA_DIR/BepInEx/plugins/map_data"

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
    fi


    if [ "''${VALHEIM_QOL_PWONCE:-0}" = "1" ]; then

      link_path "${pwonce}/plugins/ServerPasswordOnce.dll" "$DATA_DIR/BepInEx/plugins/ServerPasswordOnce.dll"
    fi

    if [ "''${VALHEIM_QOL_AUTOSAVE:-0}" = "1" ]; then

      link_path "${autosave}/plugins/AutoSaveInterval.dll" "$DATA_DIR/BepInEx/plugins/AutoSaveInterval.dll"
    fi
  '';
}
