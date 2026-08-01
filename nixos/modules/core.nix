{ lib, inputs, ... }:
{
  options = {
    sccl.ui.enable = lib.mkEnableOption "Stylix + greetd display manager";
    sccl.audio.enable = lib.mkEnableOption "PipeWire audio";
    sccl.bluetooth.enable = lib.mkEnableOption "Bluetooth + Blueman";
    sccl.net.enable = lib.mkEnableOption "NetworkManager + proxy + firewall";
    sccl.automount.enable = lib.mkEnableOption "udisks2 USB automount";
    sccl.secrets.enable = lib.mkEnableOption "sops-nix secrets";
    sccl.zapret.enable = lib.mkEnableOption "zapret DPI bypass";
    sccl.flclashx.enable = lib.mkEnableOption "FlClashX proxy GUI";
    sccl.playground.enable = lib.mkEnableOption "Docker + dev tools";
    sccl.chaotic.enable = lib.mkEnableOption "chaotic-nyx repo";
    sccl.nix-ld.enable = lib.mkEnableOption "nix-ld for binaries";
    sccl.bootstrap = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Use bootstrap profile (minimal) instead of full user profile";
    };
  };

  imports = [
    ./boot.nix
    ./nix.nix
    ./env.nix
    ./keyboard.nix
    ./timezone.nix
    ./system-packages.nix
    ./display-manager.nix
    ./stylix.nix
    ./audio.nix
    ./xdg-portal.nix
    ./bluetooth.nix
    ./net.nix
    ./automount.nix
    ./secrets.nix
    ./zapret.nix
    ./flclashx.nix
    ./playground.nix
    ./nix-ld.nix
  ];

}
