{ config, pkgs, ... }:
{
  home = {
    username = "bootstrap";
    homeDirectory = "/home/bootstrap";
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
