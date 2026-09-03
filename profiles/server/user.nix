{ config, lib, pkgs, ... }:

lib.mkIf config.sccl.server.enable {
  users.users.heimdall = {
    isNormalUser = true;
    extraGroups = [ "wheel" "docker" ];
    shell = pkgs.fish;
    initialPassword = "changeme";
  };

  programs.fish.enable = true;
  security.sudo.wheelNeedsPassword = false;
}
