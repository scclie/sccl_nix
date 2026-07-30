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
      extraGroups = [ "audio" "video" "users" ];
    };
    users.groups.paper-dis = {};

  system.activationScripts.paper-dis-acl = ''
    ${pkgs.acl}/bin/setfacl -m u:paper-dis:r-x /home/paper
    chmod g+rx /home/paper
  '';

  programs.fish.enable = true;
  security.sudo.wheelNeedsPassword = false;
}
