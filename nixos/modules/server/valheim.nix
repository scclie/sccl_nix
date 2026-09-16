{ config, lib, pkgs, ... }:
let
  cfg = config.sccl.valheim;
  dataDir = "/tank/data/valheim";
  steamEnv = "${pkgs.steam-run}/bin/steam-run";
in {
  options.sccl.valheim = {
    enable = lib.mkEnableOption "Valheim dedicated server (steamcmd anonymous install)";
    name = lib.mkOption {
      type = lib.types.str;
      default = "laeradr";
      description = "Server name shown in the community list";
    };
    world = lib.mkOption {
      type = lib.types.str;
      default = "Midgard";
      description = "World name";
    };
    port = lib.mkOption {
      type = lib.types.port;
      default = 2456;
      description = "Game port (port+1 is also used)";
    };
  };

  config = lib.mkIf cfg.enable {
    users.users.valheim = {
      isSystemUser = true;
      group = "valheim";
      home = dataDir;
      description = "Valheim dedicated server";
    };
    users.groups.valheim = { };

    sops.secrets."valheim/server-password" = {
      sopsFile = ../../../secrets/apps.yaml;
    };
    sops.secrets."valheim/steam-user" = {
      sopsFile = ../../../secrets/apps.yaml;
    };
    sops.templates."valheim-env" = {
      content = ''
        VALHEIM_PASSWORD=${config.sops.placeholder."valheim/server-password"}
        VALHEIM_STEAM_USER=${config.sops.placeholder."valheim/steam-user"}
      '';
      path = "/etc/nixos/secrets/valheim.env";
      mode = "0400";
      owner = "valheim";
    };

    systemd.services.valheim = {
      description = "Valheim dedicated server";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        Type = "simple";
        User = "valheim";
        Group = "valheim";
        WorkingDirectory = dataDir;
        EnvironmentFile = config.sops.templates."valheim-env".path;
        ExecStartPre = pkgs.writers.writeBash "valheim-prestart" ''
          ${steamEnv} ${pkgs.steamcmd}/bin/steamcmd +@sSteamCmdForcePlatformType linux +force_install_dir ${dataDir} +login $VALHEIM_STEAM_USER +app_license_request 896660 +app_update 896660 validate +quit || echo 'steamcmd update skipped (session expired? bootstrap again manually)'
          # valheim needs steamclient.so via ~/.steam/sdk64
          mkdir -p ${dataDir}/.steam/sdk64
          ln -sf ${dataDir}/.local/share/Steam/linux64/steamclient.so ${dataDir}/.steam/sdk64/steamclient.so
          test -x ${dataDir}/valheim_server.x86_64
        '';
        ExecStart = "${steamEnv} ${dataDir}/valheim_server.x86_64 -name \"${cfg.name}\" -world \"${cfg.world}\" -port ${toString cfg.port} -password $VALHEIM_PASSWORD -public false";
        Restart = "on-failure";
        RestartSec = "10s";
        # the game crashes with SIGSEGV on shutdown sometimes - don't bother
        SuccessExitStatus = [ 143 ];
      };
      environment = {
        SteamAppId = "892970";
        TEMP = "/tmp";
        TMPDIR = "/tmp";
      };
    };

    networking.firewall.allowedUDPPorts = [ cfg.port (cfg.port + 1) (cfg.port + 2) ];
  };
}
