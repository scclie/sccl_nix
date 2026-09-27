{ config, pkgs, lib, inputs, hasSecrets ? false, mailPasswordPath ? "/run/secrets/mail/app-password", ... }:

{
  imports = [
    ../shared/packages.nix
    ../shared/modules
    ./packages.nix
    ./modules
  ];

  _module.args = {
    inherit mailPasswordPath;
  };

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
}
