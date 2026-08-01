{ config, lib, pkgs, ... }:
{
  services.xserver.videoDrivers = [ "amdgpu" ];
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
    extraPackages = with pkgs; [ rocmPackages.clr.icd ];
  };
  environment.systemPackages = with pkgs; [ clinfo rocmPackages.rocm-smi ];
  environment.variables.AMD_VULKAN_ICD = "RADV";
}
