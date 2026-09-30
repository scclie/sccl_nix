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

  # landing.html
  landingRoot = pkgs.runCommand "valheim-landing" { } ''
    mkdir -p "$out"
    cp ${./landing.html} "$out/index.html"
    substituteInPlace "$out/index.html" \
      --replace-fail '@@ADDRESS@@' ${lib.escapeShellArg landingHost} \
      --replace-fail '@@GAME_PORT@@' ${lib.escapeShellArg (toString cfg.port)} \
      --replace-fail '@@MAP_URL@@' ${lib.escapeShellArg "https://${mapHost}"} \
      --replace-fail '@@STATUS_URL@@' ${lib.escapeShellArg statusUrl} \
      ${lib.optionalString (cfg.discordInvite != "") "--replace-fail '@@DISCORD_INVITE@@' ${lib.escapeShellArg cfg.discordInvite}"}${lib.optionalString (cfg.matrixRoom != "") " --replace-fail '@@MATRIX_URL@@' ${lib.escapeShellArg cfg.matrixRoom}"}
    ${lib.optionalString (cfg.webmap.enable == false) "${pkgs.gnused}/bin/sed -i '/<!--map:start-->/,/<!--map:end-->/d' \"$out/index.html\""}
    ${lib.optionalString (cfg.discordInvite == "") "${pkgs.gnused}/bin/sed -i '/<!--discord:start-->/,/<!--discord:end-->/d' \"$out/index.html\""}
    ${lib.optionalString (cfg.matrixRoom == "") "${pkgs.gnused}/bin/sed -i '/<!--matrix:start-->/,/<!--matrix:end-->/d' \"$out/index.html\""}
    # the markers are build-time scaffolding, not page content
    ${pkgs.gnused}/bin/sed -i '/<!--map:start-->/d; /<!--map:end-->/d; /<!--discord:start-->/d; /<!--discord:end-->/d; /<!--matrix:start-->/d; /<!--matrix:end-->/d' "$out/index.html"
    # a dropped marker still exits 0, so a surviving @@TOKEN@@ must fail the build
    ! grep -q '@@' "$out/index.html" || {
      echo "valheim-landing: an unsubstituted @@TOKEN@@ survived into the page" >&2
      exit 1
    }
  '';

  # the launch goes through a generated script. the doorstop variables must reach the inner
  # command inside the steam-run sandbox, see the unit below. and systemd expands $VAR
  # inside ExecStart with no "$@", so an inline `exec ... "$@"` drops the game's arguments;
  # expansion belongs in the inner shell, where $VALHEIM_PASSWORD comes from the EnvironmentFile.
  startScript = pkgs.writeShellScript "valheim-start" ''
    exec ${steamEnv} /bin/sh -c '
      # export, not a bare assignment: a shell variable never reaches the game, a child process
      export DOORSTOP_ENABLED=1
      # the data dir, not the store path: BepInEx.Preloader derives the BepInEx root from
      # its own assembly, so a store path leaves it read-only: no LogOutput.log, no
      # config/BepInEx.cfg, no mod, no log. BepInEx/core is a store symlink, so the
      # preloader reaches the real DLL and the root stays writable. doorstop_config.ini
      # ships the relative "BepInEx\core\BepInEx.Preloader.dll", overridden because the
      # backslash may not translate on Linux.
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
        -public 1
    '
  '';

  deployScript = import ./deploy.nix {
    inherit pkgs;
    inherit dataDir steamEnv;
    bepinex = mods.bepinex;
    steamcmd = "${pkgs.steamcmd}/bin/steamcmd";
    rcon = mods.rcon;
    rconPort = cfg.rcon.port;
    # comma separated, no space after it: this BepInEx build does not strip quotes
    # and a bare TOML value cannot hold whitespace, so "1.1.1.0/24, 2.2.2.0/24" can
    # be written neither quoted nor bare. the mod splits the value on "," itself.
    rconCidrs = lib.concatStringsSep "," cfg.rcon.allowedCidrs;
    discord = mods.discord;
    webmap = mods.webmap;
    webmapPort = cfg.webmap.port;
    webmapHost = mapHost;
    webmapInvite = cfg.discordInvite;
    pwonce = mods.pwonce;
    autosave = mods.autosave;
  };
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
    };

    config.assertions = [
      {
        assertion = cfg.port <= 65533;
        message = "sccl.valheim.port must leave room for port+1 and rcon.port (port+2).";
      }
    ];
  };

  config = lib.mkIf cfg.enable {
    # the ZFS parent dataset /tank/data is unmounted, so the path may not exist at all.
    # both units run as User=valheim, and the deploy's first write, `mkdir -p "$DATA_DIR/..."`,
    # fails EACCES under a root-owned /tank and leaves valheim.service dead. this is a
    # directory, not a dataset: see the dataDir option.
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
      # the doorstop variables are deliberately absent from `environment` below: the inner
      # command sets them inside the sandbox. reproduced: with DOORSTOP_ENABLED=1 in the
      # environment doorstop loads into the `bwrap` that steam-run execs and bwrap dies
      # with "Can't make symlink at /bin" before the game starts. LD_PRELOAD alone is harmless.
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
      };
    };
  };
}
