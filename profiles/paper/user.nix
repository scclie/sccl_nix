{ config, lib, pkgs, ... }:

lib.mkIf (!config.sccl.bootstrap) {
  users.users.paper = {
    isNormalUser = true;
    description = "Paper";
    extraGroups = [ "networkmanager" "wheel" "video" "audio" "docker" ];
    shell = pkgs.fish;
    initialPassword = "change"; # initial psswd
  };

    programs.fish.enable = true;
    security.sudo.wheelNeedsPassword = false;
  }
