{ config, pkgs, ... }:

{
  # Main user
  users.users.paper = {
    isNormalUser = true;
    description = "Paper"; # tipo bumaga?
    extraGroups = [ "networkmanager" "wheel" "video" "audio" "docker" ];
    shell = pkgs.fish;
    initialPassword = "change"; # initial psswd, dont forget to change
  };

  # Discord user
  users.users.paper-dis = {
      isSystemUser = true;
      group = "paper-dis";
      extraGroups = [ "audio" "video" ];
    };
    users.groups.paper-dis = {};

  programs.fish.enable = true;
  security.sudo.wheelNeedsPassword = false;
}
