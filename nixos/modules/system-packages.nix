{ config, pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    vim wget curl git htop tree nano fastfetch hyfetch
    p7zip unzip zip
    networkmanagerapplet
  ];
}
