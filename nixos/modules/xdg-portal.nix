{ config, pkgs, lib, ... }:
let cfg = config.sccl.audio;
in {
  config = lib.mkIf cfg.enable {
    xdg.portal = {
      enable = true;
      extraPortals = [
        pkgs.xdg-desktop-portal-gnome
        pkgs.xdg-desktop-portal-gtk
      ];
      config = {
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
