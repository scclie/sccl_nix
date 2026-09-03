{ config, lib, pkgs, ... }:
let
  cfg = config.sccl.status;

  gatusConfig = {
    web = {
      address = "0.0.0.0";
      port = 8080;
    };
    storage = {
      type = "sqlite";
      path = "/tank/mon/gatus/db";
    };
    endpoints = map (ep: {
      name = ep.name;
      url = ep.url;
      interval = ep.interval;
      conditions = [
        "[STATUS] == 200"
        "[RESPONSE_TIME] < 5000"
      ];
    }) cfg.endpoints;
  };

  gatusConfigFile = pkgs.writeText "gatus-config.yaml" (builtins.toJSON gatusConfig);
in {
  options.sccl.status = {
    enable = lib.mkEnableOption "Gatus public status page";

    endpoints = lib.mkOption {
      type = lib.types.listOf (lib.types.submodule {
        options = {
          name = lib.mkOption { type = lib.types.str; };
          url = lib.mkOption { type = lib.types.str; };
          interval = lib.mkOption {
            type = lib.types.str;
            default = "1m";
          };
        };
      });
      default = [];
      description = "Endpoints to monitor";
    };
  };

  config = lib.mkIf cfg.enable {
    # Ensure data directory exists
    system.activationScripts.gatus-dirs = lib.mkAfter ''
      mkdir -p /tank/mon/gatus
    '';

    systemd.services.gatus = {
      description = "Gatus status page";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        ExecStart = "${pkgs.gatus}/bin/gatus --config ${gatusConfigFile}";
        Restart = "always";
        RestartSec = 5;
        StateDirectory = "gatus";
      };
    };

    # Expose via nginx proxy
    sccl.proxy.sites = {
      status = {
        upstream = "http://127.0.0.1:8080";
      };
    };
  };
}
