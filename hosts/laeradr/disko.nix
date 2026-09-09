{
  disko.devices = {
    disk = {
      main = {
        type = "disk";
        device = "/dev/disk/by-id/ata-Apacer_AS350_1TB_E15C0736039001802270";
        content = {
          type = "gpt";
          partitions = {
            ESP = {
              size = "512M";
              type = "EF00";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
              };
            };
            root = {
              size = "100%";
              content = {
                type = "zfs";
                pool = "tank";
              };
            };
          };
        };
      };
    };

    zpool = {
      tank = {
        type = "zpool";
        rootFsOptions = {
          compression = "zstd";
          atime = "off";
          mountpoint = "none";
        };

        datasets = {
          root = {
            type = "zfs_fs";
            mountpoint = "/";
            options."com.sun:auto-snapshot" = "true";
          };
          nix = {
            type = "zfs_fs";
            mountpoint = "/nix";
            options.quota = "200G";
          };
          data = {
            type = "zfs_fs";
            # Parent dataset - not mounted, only children are mounted
          };
          "data/sites" = {
            type = "zfs_fs";
            mountpoint = "/tank/sites";
          };
          "data/apps" = {
            type = "zfs_fs";
            mountpoint = "/tank/apps";
          };
          "data/forgejo" = {
            type = "zfs_fs";
            mountpoint = "/tank/forgejo";
          };
          "data/db" = {
            type = "zfs_fs";
            mountpoint = "/tank/db";
          };
          "data/mail" = {
            type = "zfs_fs";
            mountpoint = "/tank/mail";
          };
          "data/sftpgo" = {
            type = "zfs_fs";
            mountpoint = "/tank/sftpgo";
          };
          "data/minecraft" = {
            type = "zfs_fs";
            mountpoint = "/tank/minecraft";
          };
          "data/vw" = {
            type = "zfs_fs";
            mountpoint = "/tank/vw";
          };
          "data/mon" = {
            type = "zfs_fs";
            mountpoint = "/tank/mon";
          };
          "data/matrix" = {
            type = "zfs_fs";
            mountpoint = "/tank/matrix";
          };
          "data/music" = {
            type = "zfs_fs";
            mountpoint = "/tank/music";
          };
          backups = {
            type = "zfs_fs";
            mountpoint = "/tank/backups";
          };
          swap = {
            type = "zfs_volume";
            size = "8G";
            content = {
              type = "swap";
            };
          };
        };
      };
    };
  };
}
