{ config, lib, pkgs, ... }:
let
  cfg = config.sccl.radio;
in {
  options.sccl.radio = {
    enable = lib.mkEnableOption "Radio service (stub — app spec separate)";
  };

  config = lib.mkIf cfg.enable {
    # Placeholder: IP .15, datasets /tank/data/radio + /tank/music
    # DB in db-ct (radio database initialized in Task 2.3)
    # vhost radio.sccl.cc + facade api.sccl.cc/radio reserved
  };
}
