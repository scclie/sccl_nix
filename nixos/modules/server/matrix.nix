{ config, lib, pkgs, ... }:
let
  cfg = config.sccl.matrix;
in {
  options.sccl.matrix = {
    enable = lib.mkEnableOption "Matrix Synapse (stub — deploys after domain purchase)";
  };

  config = lib.mkIf cfg.enable {
    # Placeholder: reserved IP .19, dataset /tank/data/matrix
    # Actual deployment deferred until separate domain is purchased
    # WARNING: server_name is immutable after first user — decide BEFORE deploy

    # When ready, uncomment and configure:
    # containers.matrix-ct = {
    #   autoStart = true;
    #   ephemeral = true;
    #   privateNetwork = true;
    #   hostAddress = "10.69.0.1";
    #   localAddress = "10.69.0.19";
    #   hostBridge = "br-svc";
    #   bindMounts = {
    #     "/var/lib/matrix-synapse" = {
    #       hostPath = "/tank/data/matrix";
    #       isReadOnly = false;
    #     };
    #   };
    #   config = { config, pkgs, ... }: {
    #     system.stateVersion = "26.05";
    #     services.matrix-synapse = {
    #       enable = true;
    #       settings.server_name = "matrix.example.com";  # MUST be decided before first user
    #       settings.database.params.database = "/var/lib/matrix-synapse/homeserver.db";
    #     };
    #   };
    # };

    # Federation port
    # networking.firewall.allowedTCPPorts = [ 8448 ];
  };
}
