{ config, pkgs, ... }:

{
  xdg.portal = {
    enable = true;
    extraPortals = [
      pkgs.xdg-desktop-portal-gnome  # ScreenCast/Screenshot (через pipewire)
      pkgs.xdg-desktop-portal-gtk    # OpenURI, FileChooser
    ];
    configPackages = [ pkgs.niri ];
    config = {
      niri = {
        default = [ "gnome" "gtk" ];
        "org.freedesktop.impl.portal.ScreenCast"  = [ "gnome" ];
        "org.freedesktop.impl.portal.Screenshot"  = [ "gnome" ];
        "org.freedesktop.impl.portal.OpenURI"     = [ "gtk" ];
        "org.freedesktop.impl.portal.FileChooser" = [ "gtk" ];
      };
      common = {
        default = [ "gtk" ];
      };
    };
  };

  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    wireplumber.enable = true;
  };

  environment.systemPackages = with pkgs; [
    xdg-desktop-portal
    xdg-desktop-portal-gnome
    xdg-desktop-portal-gtk
    gnome-keyring
  ];

  environment.sessionVariables = {
    NIXOS_XDG_OPEN_USE_PORTAL = "1";
  };
}
