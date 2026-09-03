{ config, lib, pkgs, ... }:

{
  boot = {
    loader = {
      systemd-boot.enable = true; # using systemd-boot instead of grub
      efi.canTouchEfiVariables = true;
      timeout = 3;
    };

    kernelPackages = if config.sccl.boot.cachyos
      then lib.mkForce pkgs.linuxPackages_cachyos
      else pkgs.linuxPackages;

    plymouth.enable = config.sccl.boot.cachyos;
    kernelParams = lib.optionals config.sccl.boot.cachyos [ "quiet" "splash" ];
  };

  boot.supportedFilesystems = lib.optionals (!config.sccl.boot.cachyos) [ "zfs" ];
}
