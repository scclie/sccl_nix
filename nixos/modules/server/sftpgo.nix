{ config, lib, pkgs, ... }:
let
  cfg = config.sccl.sftpgo;
in {
  options.sccl.sftpgo = {
    enable = lib.mkEnableOption "SFTPGo file sharing";
  };

  config = lib.mkIf cfg.enable {
    containers.files-ct = {
      autoStart = true;
      ephemeral = true;
      privateNetwork = true;
      hostAddress = "10.69.0.1";
      localAddress = "10.69.0.11";
      hostBridge = "br-svc";

      bindMounts = {
        "/var/lib/sftpgo" = {
          hostPath = "/tank/sftpgo";
          isReadOnly = false;
        };
      };

      config = { config, pkgs, lib, ... }: {
        system.stateVersion = "26.05";

        nixpkgs.config.allowUnfreePredicate = pkg:
          builtins.elem (lib.getName pkg) [ "sftpgo" ];

        services.sftpgo = {
          enable = true;
          dataDir = "/var/lib/sftpgo/data";
          settings = {
            httpd.bindings = [{
              address = "0.0.0.0";
              port = 8080;
              enable_web_admin = true;
              enable_web_client = true;
            }];
            sftpd.bindings = [{
              address = "0.0.0.0";
              port = 2022;
            }];
            provider.sqlite.database_path = "/var/lib/sftpgo/data/db";
          };
        };

        networking.firewall = {
          allowedTCPPorts = [ 8080 2022 ];
        };
      };
    };

    sccl.proxy.sites = {
      files = {
        upstream = "http://10.69.0.11:8080";
      };
    };
  };
}
