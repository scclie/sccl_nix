{ config, pkgs, lib, inputs, hasSecrets ? false, ... }:

{
  imports = [
    ../shared/packages.nix
    ../shared/modules
    ./packages.nix
    ./modules
  ];

  home = {
    username = "paper";
    homeDirectory = "/home/paper";
    stateVersion = "26.05";
  };

  programs.home-manager.enable = true;

  stylix.targets = {
    fish.enable = true;
    vim.enable = true;
    gtk.enable = true;
    rofi.enable = false;
  };

  gtk.theme.name = lib.mkForce "adw-gtk3-dark";

  xdg.desktopEntries.vesktop = {
    name = "Vesktop (Secured)";
    genericName = "Discord Client";
    exec = "vesktop %U";
    icon = "vesktop";
    type = "Application";
    categories = [ "Network" "Chat" "InstantMessaging" ];
    terminal = false;
    mimeType = [ "x-scheme-handler/discord" ];
  };
}
