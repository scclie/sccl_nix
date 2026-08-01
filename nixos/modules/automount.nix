{ config, lib, pkgs, ... }:
let cfg = config.sccl.automount;
in {
  config = lib.mkIf cfg.enable {
    services.udisks2.enable = true;
    security.polkit.enable = true;
    services.gvfs.enable = true;
  };
}
