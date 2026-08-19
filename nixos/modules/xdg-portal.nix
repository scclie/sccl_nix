{ config, pkgs, lib, ... }:
let cfg = config.sccl.ui;
in {
  config = lib.mkIf cfg.enable {
    xdg.portal = {
      enable = true;
      extraPortals = [
        pkgs.xdg-desktop-portal-gnome
        pkgs.xdg-desktop-portal-gtk
      ];
      configPackages = [ pkgs.niri ];
      config = {
        niri = {
          default = [ "gnome" "gtk" ];
          "org.freedesktop.impl.portal.ScreenCast" = [ "gnome" ];
          "org.freedesktop.impl.portal.Screenshot" = [ "gnome" ];
          "org.freedesktop.impl.portal.OpenURI" = [ "gtk" ];
          "org.freedesktop.impl.portal.FileChooser" = [ "gtk" ];
        };
        common = {
          default = [ "gtk" ];
        };
      };
    };

    environment.sessionVariables = {
      NIXOS_XDG_OPEN_USE_PORTAL = "1";
    };

    environment.systemPackages = with pkgs; [
      xdg-desktop-portal
      xdg-desktop-portal-gnome
      xdg-desktop-portal-gtk
      gnome-keyring
    ];
  };
}
