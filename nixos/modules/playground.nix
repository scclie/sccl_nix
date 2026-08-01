{ config, lib, pkgs, ... }:
let cfg = config.sccl.playground;
in {
  config = lib.mkIf cfg.enable {
    virtualisation.docker = {
      enable = true;
      autoPrune.enable = true;
    };
    networking.firewall.allowedTCPPorts = [ 2375 2376 ];
  };
}
