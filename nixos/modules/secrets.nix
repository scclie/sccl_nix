{ config, lib, pkgs, ... }:
let cfg = config.sccl.secrets;
in {
  config = lib.mkIf cfg.enable { };
}
