{ config, lib, pkgs, ... }:
lib.mkIf config.sccl.bootstrap {
  users.users.bootstrap = {
    isNormalUser = true;
    description = "Bootstrap user";
    extraGroups = [ "networkmanager" "wheel" "video" "audio" ];
    shell = pkgs.fish;
    initialPassword = "bootstrap";
  };

  programs.fish.enable = true;
  security.sudo.wheelNeedsPassword = false;
}

