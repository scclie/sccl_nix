{ config, lib, pkgs, ... }:
let
  cfg = config.sccl.backup;
in {
  options.sccl.backup = {
    enable = lib.mkEnableOption "sanoid + restic backups";

    resticRepository = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = "restic repository URL (S3-compatible)";
    };

    resticPasswordFile = lib.mkOption {
      type = lib.types.str;
      default = "/run/secrets/restic/password";
      description = "Path to restic password file";
    };

    resticS3AccessKeyFile = lib.mkOption {
      type = lib.types.str;
      default = "/run/secrets/restic/s3-access-key";
      description = "Path to S3 access key file";
    };

    resticS3SecretKeyFile = lib.mkOption {
      type = lib.types.str;
      default = "/run/secrets/restic/s3-secret-key";
      description = "Path to S3 secret key file";
    };
  };

  config = lib.mkIf cfg.enable {
    # Ensure backup dataset exists
    system.activationScripts.backup-dirs = lib.mkAfter ''
      mkdir -p /tank/backups
    '';

    # Sanoid for ZFS snapshots
    services.sanoid = {
      enable = true;
      templates = {
        "frequent" = {
          hourly = 24;
          daily = 7;
          weekly = 4;
          monthly = 3;
          autosnap = true;
          autoprune = true;
        };
        "default" = {
          hourly = 24;
          daily = 7;
          weekly = 4;
          monthly = 3;
          autosnap = true;
          autoprune = true;
        };
      };
      datasets = {
        "tank/root" = {
          useTemplate = [ "frequent" ];
        };
        "tank/data" = {
          useTemplate = [ "default" ];
        };
      };
    };

    # Restic offsite backup
    sops.secrets."restic/password" = {
      sopsFile = ../../../secrets/apps.yaml;
    };
    sops.secrets."restic/s3-access-key" = {
      sopsFile = ../../../secrets/apps.yaml;
    };
    sops.secrets."restic/s3-secret-key" = {
      sopsFile = ../../../secrets/apps.yaml;
    };

    systemd.services.restic-backup = {
      description = "Restic offsite backup";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = pkgs.writeShellScript "restic-backup" ''
          set -euo pipefail

          export AWS_ACCESS_KEY_ID=$(cat ${cfg.resticS3AccessKeyFile})
          export AWS_SECRET_ACCESS_KEY=$(cat ${cfg.resticS3SecretKeyFile})

          ${pkgs.restic}/bin/restic backup \
            --repo ${cfg.resticRepository} \
            --password-file ${cfg.resticPasswordFile} \
            --verbose \
            /tank/data /tank/forgejo /tank/db /tank/mail /tank/vw /tank/mon /tank/apps /tank/gifs /tank/sites

          ${pkgs.restic}/bin/restic forget \
            --repo ${cfg.resticRepository} \
            --password-file ${cfg.resticPasswordFile} \
            --keep-daily 7 \
            --keep-weekly 4 \
            --keep-monthly 3 \
            --prune
        '';
      };
    };

    systemd.timers.restic-backup = {
      description = "Daily restic backup";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "daily";
        Persistent = true;
      };
    };
  };
}
