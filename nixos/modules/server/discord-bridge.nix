{ config, lib, pkgs, ... }:
let
  cfg = config.sccl.discordBridge;

  jq = "${pkgs.jq}/bin/jq";
  curl = "${pkgs.curl}/bin/curl";

  # continuwuity has no config-file appservices support: registration must be
  # pushed as an admin command in the #admins room (persisted in its DB).
  registerScript = pkgs.writeShellScript "discord-bridge-register" ''
    set -euo pipefail
    HS="${cfg.homeserverAddress}"
    REG=/tank/discord-bridge/discord-registration.yaml
    STATE=/var/lib/discord-bridge-register/state
    ADMIN_TOKEN=$(cat /run/secrets/discord/mautrix-admin-access-token)

    [ -f "$REG" ] || { echo "registration file not generated yet"; exit 1; }

    mkdir -p /var/lib/discord-bridge-register
    # v2: state version bumped after the first (broken) body encoding run
    WANT=$( (cat "$REG"; printf %s "$ADMIN_TOKEN"; printf 'v2') | ${pkgs.coreutils}/bin/sha256sum | cut -d' ' -f1)
    [ -f "$STATE" ] && [ "$(cat "$STATE")" = "$WANT" ] && exit 0

    ROOM=$(${curl} -sf "$HS/_matrix/client/v3/directory/room/%23admins:${cfg.domain}" \
      -H "Authorization: Bearer $ADMIN_TOKEN" | ${jq} -r .room_id)

    # -r: raw output so real newlines land in the message body (the admin
    # command parser needs the yaml in a fenced block on its own lines)
    BODY=$(${jq} -rn --arg y "$(cat "$REG")" '"!admin appservices register\n```\n" + $y + "\n```"')
    ${curl} -sf -XPUT "$HS/_matrix/client/v3/rooms/$ROOM/send/m.room.message/$(date +%s%N)" \
      -H "Authorization: Bearer $ADMIN_TOKEN" -H "Content-Type: application/json" \
      -d "$(${jq} -cn --arg b "$BODY" '{msgtype:"m.text",body:$b}')"

    printf '%s\n' "$WANT" > "$STATE"
  '';

  loginScript = let
    jq = "${pkgs.jq}/bin/jq";
    curl = "${pkgs.curl}/bin/curl";
  in pkgs.writeShellScript "discord-bridge-login" ''
    set -euo pipefail
    HS="${cfg.homeserverAddress}"
    STATE=/var/lib/discord-bridge-login/state
    TOKEN=$(cat /run/secrets/discord/draumur-bot-token)
    ADMIN_TOKEN=$(cat /run/secrets/discord/mautrix-admin-access-token)
    BOT=${cfg.bridgeBot}
    AUTH="Authorization: Bearer $ADMIN_TOKEN"

    mkdir -p /var/lib/discord-bridge-login
    # v3: bot tokens need `login-token bot <token>`
    WANT=$( (printf %s "$TOKEN"; printf 'v3') | ${pkgs.coreutils}/bin/sha256sum | cut -d' ' -f1)
    if [ -f "$STATE" ] && [ "$(cut -d' ' -f1 "$STATE")" = "$WANT" ]; then
      exit 0
    fi
    ROOM=$(cut -d' ' -f2 "$STATE" 2>/dev/null || true)

    if [ -z "$ROOM" ]; then
      ROOM=$(${curl} -sf -XPOST "$HS/_matrix/client/v3/createRoom" \
        -H "$AUTH" -H "Content-Type: application/json" \
        -d "$(${jq} -cn --arg b "$BOT" '{invite:[$b],is_direct:true,preset:"trusted_private_chat",name:"discord"}' )" \
        | ${jq} -r .room_id)
    fi

    # (re)invite the bot: on the first ever run it may not have been an
    # appservice user yet, so the invite has to be delivered again
    ${curl} -sf -XPOST "$HS/_matrix/client/v3/rooms/$ROOM/invite" \
      -H "$AUTH" -H "Content-Type: application/json" \
      -d "$(${jq} -cn --arg b "$BOT" '{user_id:$b}')" >/dev/null || true

    # wait for the bot to join (appservice bots auto-join invites)
    for i in $(seq 1 30); do
      M=$(${curl} -sf "$HS/_matrix/client/v3/sync?set_presence=offline&timeout=0" -H "$AUTH" \
        | ${jq} -r --arg r "$ROOM" '.rooms.join[$r].timeline.events[]?.content.membership // empty' | tail -1) || true
      [ "$M" = "join" ] && break
      sleep 2
    done

    TXN=$(date +%s)
    ${curl} -sf -XPUT "$HS/_matrix/client/v3/rooms/$ROOM/send/m.room.message/$TXN" \
      -H "$AUTH" -H "Content-Type: application/json" \
      -d "$(${jq} -cn --arg t "$TOKEN" '{msgtype:"m.text",body:("login-token bot \($t)")}')"

    printf '%s %s\n' "$WANT" "$ROOM" > "$STATE"
  '';
in {
  options.sccl.discordBridge = {
    enable = lib.mkEnableOption "mautrix-discord bridge (host), pierdol.ing";
    homeserverAddress = lib.mkOption {
      type = lib.types.str;
      default = "http://10.69.0.19:6167";
      description = "Container-side continnuity client API used by the bridge over br-svc";
    };
    domain = lib.mkOption {
      type = lib.types.str;
      default = "pierdol.ing";
    };
    bridgeBot = lib.mkOption {
      type = lib.types.str;
      default = "@discordbot:pierdol.ing";
      description = "Matrix MXID of the bridge bot (appservice bot), from registration shown to the module.";
    };
    admin = lib.mkOption {
      type = lib.types.str;
      default = "@sccl:pierdol.ing";
    };
  };

  config = lib.mkIf cfg.enable {
    sops.secrets."discord/draumur-bot-token" = {
      sopsFile = ../../../secrets/apps.yaml;
      restartUnits = [ "discord-bridge-login.service" ];
    };
    sops.secrets."discord/mautrix-admin-access-token" = {
      sopsFile = ../../../secrets/apps.yaml;
      restartUnits = [ "discord-bridge-login.service" ];
    };

    services.mautrix-discord = {
      enable = true;
      dataDir = "/tank/discord-bridge";
      settings = {
        homeserver = {
          domain = cfg.domain;
          address = cfg.homeserverAddress;
        };
        appservice = {
          # url the homeserver (in matrix-ct) uses to reach the bridge; the
          # host side of br-svc is 10.69.0.1. must not be loopback.
          address = "http://10.69.0.1:29334";
          hostname = "0.0.0.0";
          port = 29334;
          bot_username = "discordbot";
          database = {
            type = "sqlite3";
            uri = "file:${config.services.mautrix-discord.dataDir}/mautrix-discord.db?_txlock=immediate";
          };
        };
        bridge = {
          permissions = {
            "${cfg.admin}" = "admin";
            "${cfg.domain}" = "user";
          };
          public_address = "https://discord-bridge.pierdol.ing";
          # matrix users without their own discord login are posted through a
          # webhook with their own name/avatar (seamless relay)
          enable_webhook_avatars = true;
          prefix_webhook_messages = false;
          encryption = { allow = true; default = false; };
        };
      };
    };

    systemd.tmpfiles.rules = [
      "d /tank/discord-bridge 0750 mautrix-discord mautrix-discord -"
    ];

    # homeserver -> appservice transactions come from matrix-ct over br-svc
    networking.firewall.interfaces.br-svc.allowedTCPPorts = [ 29334 ];

    systemd.services.discord-bridge-register = {
      description = "Register mautrix-discord appservice with continuwuity";
      after = [ "mautrix-discord-registration.service" "network-online.target" ];
      wants = [ "mautrix-discord-registration.service" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        StateDirectory = "discord-bridge-register";
        ExecStart = registerScript;
        # homeserver may come up later (container); retry until it answers
        Restart = "on-failure";
        RestartSec = "15s";
      };
    };

    systemd.services.discord-bridge-login = {
      description = "Auto-login mautrix-discord bridge bot from sops secret";
      after = [ "mautrix-discord.service" "discord-bridge-register.service" ];
      requires = [ "mautrix-discord.service" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        StateDirectory = "discord-bridge-login";
        ExecStart = loginScript;
        # homeserver may come up later (container); retry until it answers
        Restart = "on-failure";
        RestartSec = "15s";
      };
    };
  };
}
