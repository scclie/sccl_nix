{ config, pkgs, lib, ... }:

{
  gtk = {
    enable = true;

    gtk3.extraConfig = {
      gtk-application-prefer-dark-theme = true;
    };

    gtk4.extraConfig = {
      gtk-application-prefer-dark-theme = true;
    };

    iconTheme = {
          name = "Nordzy-dark";
          package = pkgs.nordzy-icon-theme;
    };
  };

  xfconf.enable = lib.mkForce false;
}
