{ config, lib, pkgs, ... }:
let
  cfg = config.sccl.mail;
  containerIp = "10.69.0.9";
in {
  options.sccl.mail = {
    enable = lib.mkEnableOption "Stalwart mail server";
    domain = lib.mkOption {
      type = lib.types.str;
      default = "sccl.cc";
      description = "Mail domain";
    };
    hostname = lib.mkOption {
      type = lib.types.str;
      default = "mail.sccl.cc";
      description = "Mail server hostname";
    };
  };

  config = lib.mkIf cfg.enable {
    containers.mail = {
      autoStart = true;
      ephemeral = false;
      privateNetwork = true;
      hostAddress = "10.69.0.1";
      localAddress = containerIp;
      hostBridge = "br-svc";

      bindMounts = {
        "/var/lib/stalwart-mail" = {
          hostPath = "/tank/mail";
          isReadOnly = false;
        };
      };

      config = { pkgs, ... }: {
        system.stateVersion = "26.05";

        services.stalwart-mail = {
          enable = true;
          stateVersion = "26.05";
          settings = {
            server = {
              hostname = cfg.hostname;
              smtp = {
                max-message-size = 52428800;
                max-recipients = 100;
              };
            };
            storage = {
              data = "rocksdb";
              fts = "rocksdb";
              lookup = "rocksdb";
            };
            queue = {
              max-queue-size = 1000;
              max-rewrite-headers = 100;
              maxSize = 52428800;
            };
            session = {
              timeout = "10m";
            };
          };
        };

        systemd.tmpfiles.rules = [
          "d /var/lib/stalwart-mail 0755 stalwart-mail stalwart-mail -"
        ];
      };
    };

    sccl.proxy.sites.webmail = {
      upstream = "http://${containerIp}:8080";
    };

    networking.firewall = {
      allowedTCPPorts = [ 25 465 587 993 8448 ];
    };
  };
}
