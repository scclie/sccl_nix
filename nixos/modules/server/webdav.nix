{ config, lib, pkgs, ... }:
let
  cfg = config.sccl.files.webdav;
in {
  options.sccl.files.webdav = {
    enable = lib.mkEnableOption "WebDAV mount of the files server (davfs2)";
    url = lib.mkOption {
      type = lib.types.str;
      default = "https://files-lan.sccl.cc:8081/";
      description = "WebDAV URL of the files server";
    };
    mountHost = lib.mkOption {
      type = lib.types.str;
      default = "files-lan.sccl.cc";
      description = "Hostname used in the WebDAV URL (must match the TLS cert)";
    };
    mountAddress = lib.mkOption {
      type = lib.types.str;
      default = "192.168.0.10";
      description = "LAN address the mountHost resolves to";
    };
    mountPoint = lib.mkOption {
      type = lib.types.str;
      default = "/home/paper/Files";
      description = "Where to mount the WebDAV disk";
    };
    uid = lib.mkOption {
      type = lib.types.int;
      default = 1000;
      description = "Owner uid of the mounted filesystem";
    };
    gid = lib.mkOption {
      type = lib.types.int;
      default = 100;
      description = "Owner gid of the mounted filesystem";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = config.sccl.secrets.enable;
        message = "sccl.files.webdav.enable requires sccl.secrets.enable (davfs2/secrets in personal.yaml)";
      }
    ];

    services.davfs2.enable = true;

    services.davfs2.settings.globalSection.use_locks = false;

    security.pki.certificateFiles = [
      ../../../certs/home-ca.pem
    ];

    networking.hosts."${cfg.mountAddress}" = [ cfg.mountHost ];

    sops.secrets."davfs2/secrets" = {
      sopsFile = ../../../secrets/personal.yaml;
      path = "/etc/davfs2/secrets";
      mode = "0600";
      owner = "root";
      group = "root";
    };

    systemd.tmpfiles.rules = [
      "d ${cfg.mountPoint} 0755 paper users -"
    ];

    fileSystems."${cfg.mountPoint}" = {
      device = cfg.url;
      fsType = "davfs";
      options = [
        "noauto"
        "x-systemd.automount"
        "_netdev"
        "nofail"
        "uid=${toString cfg.uid}"
        "gid=${toString cfg.gid}"
        "file_mode=0640"
        "dir_mode=0750"
      ];
    };
  };
}
