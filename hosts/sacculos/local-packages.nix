{ config, pkgs, pkgs-unstable, ... }:

{
  environment.systemPackages = with pkgs; [
    # System utilities (available for all users)
    vim
    wget
    curl
    git
    htop
    tree
    nano
    fastfetch
    hyfetch


    # Archive tools
    p7zip
    unzip
    zip

    # Network manager
    networkmanagerapplet
  ];
}
