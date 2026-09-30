# steam-for-linux#12310.
# https://github.com/NixOS/nixpkgs/blob/c27cdad491a991b11ed731760aa2ef8db0cb0410/nixos/modules/hardware/steam-hardware.nix

{ config, lib, ... }:

let cfg = config.sccl.gamepad;
in {
  config = lib.mkIf cfg.enable {
    hardware.steam-hardware.enable = true;
  };
}
