{ config, pkgs, lib, ... }:
{
  home = {
    username = "bootstrap";
    homeDirectory = lib.mkForce "/home/bootstrap";
    stateVersion = "26.05";
  };

  programs.home-manager.enable = true;

  home.packages = with pkgs; [
    vim
    git
    curl
    wget
  ];
}
