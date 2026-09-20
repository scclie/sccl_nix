{ config, lib, pkgs, ... }:
let
  cfg = config.sccl.mirror;

  syncScript = pkgs.writeShellScript "mirror-sync" ''
    set -euo pipefail

    MIRROR_DIR="/tank/mirrors"
    LOG_FILE="$MIRROR_DIR/scripts/sync.log"

    log() {
      echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
    }

    sync_zig() {
      local version="$1"
      local target_dir="$MIRROR_DIR/zig/$version"
      local filename="zig-x86_64-linux-''${version}.tar.xz"

      if [ -f "$target_dir/$filename" ]; then
        log "Zig $version already exists"
        return 0
      fi

      mkdir -p "$target_dir"
      log "Downloading Zig $version..."

      if ${pkgs.curl}/bin/curl -L -o "$target_dir/$filename" \
          "https://ziglang.org/download/''${version}/zig-x86_64-linux-''${version}.tar.xz"; then
        log "Zig $version downloaded successfully"
      else
        log "ERROR: Failed to download Zig $version"
        rm -f "$target_dir/$filename"
        return 1
      fi
    }

    log "Starting mirror sync"

    # Zig versions to mirror
    ${lib.concatMapStringsSep "\n" (version: "sync_zig \"${version}\" || true") cfg.zig.versions}

    log "Mirror sync completed"
  '';
in {
  options.sccl.mirror = {
    enable = lib.mkEnableOption "file mirror hosting from /tank/mirrors";

    zig = {
      versions = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ "0.13.0" "0.14.0" "0.14.1" "0.15.0" "0.15.1" "0.15.2" "0.16.0" ];
        description = "Zig versions to mirror";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    services.nginx.virtualHosts."mirror.pierdol.ing" = {
      serverName = "mirror.pierdol.ing";
      root = "/tank/mirrors";
      addSSL = true;
      sslCertificate = "/var/lib/acme/wildcard.pierdol.ing/fullchain.pem";
      sslCertificateKey = "/var/lib/acme/wildcard.pierdol.ing/key.pem";
      locations."/" = {
        extraConfig = ''
          autoindex on;
          autoindex_exact_size off;
          autoindex_localtime on;
          add_header Cache-Control "public, max-age=31536000, immutable";
        '';
      };
    };

    systemd.services.mirror-sync = {
      description = "Sync mirror files from upstream";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${pkgs.bash}/bin/bash ${syncScript}";
        User = "root";
      };
    };

    systemd.timers.mirror-sync = {
      description = "Run mirror sync weekly";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "weekly";
        Persistent = true;
      };
    };
  };
}
