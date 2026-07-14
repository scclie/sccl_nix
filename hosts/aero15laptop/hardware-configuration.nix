# DO NOT EDIT — will be auto-generated during NixOS install
# Run: nixos-generate-config --root /mnt --show-hardware-config --no-filesystems > hosts/aero15laptop/hardware-configuration.nix
{ config, lib, pkgs, modulesPath, ... }:

{
  imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];

  # placeholder — replace after generating hardware config
  boot.initrd.availableKernelModules = [ ];
  boot.kernelModules = [ ];
  boot.extraModulePackages = [ ];

  fileSystems = { };
  swapDevices = [ ];

  # nixos-generate-config will populate this file
}
