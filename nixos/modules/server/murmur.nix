{ config, lib, pkgs, ... }:
let
  cfg = config.sccl.murmur;
  # Names must not contain single quotes (SQL literal).
  seedLines = lib.concatMapStringsSep "\n" (c: ''
    "$SQLITE" "$DB" "INSERT INTO channels (server_id, channel_id, parent_id, name, inheritacl) VALUES (1, $NEXT, 0, '${c}', 1)"
    NEXT=$((NEXT+1))
  '') cfg.channels;
  seedScript = pkgs.writeShellScript "murmur-channel-seed" ''
    set -euo pipefail
    SQLITE=${pkgs.sqlite}/bin/sqlite3
    DB=${config.services.murmur.stateDir}/murmur.sqlite
    [ -f "$DB" ] || exit 0

    EXISTS=$("$SQLITE" "$DB" "SELECT COUNT(*) FROM channels WHERE server_id = 1 AND parent_id IS NOT NULL")
    [ "$EXISTS" -eq 0 ] || exit 0

    NEXT=$("$SQLITE" "$DB" "SELECT COALESCE(MAX(channel_id), 0) + 1 FROM channels WHERE server_id = 1")
    ${seedLines}

    systemctl restart murmur.service
  '';
in {
  options.sccl.murmur = {
    enable = lib.mkEnableOption "Mumble voice server (Murmur)";
    channels = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = ''
        Channel names to create under Root on the first start.
        Idempotent: existing channels (beyond Root) are never touched.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    sops.secrets."murmur/server-password" = {
      sopsFile = ../../../secrets/apps.yaml;
    };
    sops.secrets."murmur/superuser-password" = {
      sopsFile = ../../../secrets/apps.yaml;
    };
    sops.templates."murmurd-env" = {
      content = ''
        MURMURD_PASSWORD=${config.sops.placeholder."murmur/server-password"}
        MURMURD_SUPERUSER_PASSWORD=${config.sops.placeholder."murmur/superuser-password"}
      '';
      path = "/etc/nixos/secrets/murmurd.env";
      mode = "0400";
    };

    services.murmur = {
      enable = true;
      stateDir = "/tank/murmur";
      registerName = "murmur.sccl.cc";
      users = 32;
      bandwidth = 96000; # default is 72000
      welcometext = "Welcome to murmur.sccl.cc - Mumble voice server";
      openFirewall = true; # TCP+UDP 64738
      password = "$MURMURD_PASSWORD";
      environmentFile = config.sops.templates."murmurd-env".path;
    };

    # SuperUser pswd
    systemd.services.murmur-superuser = {
      description = "Set Murmur SuperUser password from sops secret";
      after = [ "murmur.service" ];
      requires = [ "murmur.service" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "oneshot";
        User = "murmur";
        Group = "murmur";
        EnvironmentFile = config.sops.templates."murmurd-env".path;
        ExecStart = "${pkgs.murmur}/bin/mumble-server -ini /run/murmur/murmurd.ini -supw \$MURMURD_SUPERUSER_PASSWORD";
        ExecStartPre = "${pkgs.coreutils}/bin/sleep 3";
      };
    };

    systemd.services.murmur-channels = {
      description = "Seed Murmur channels from sccl.murmur.channels";
      after = [ "murmur.service" ];
      requires = [ "murmur.service" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = seedScript;
      };
    };
  };
}
