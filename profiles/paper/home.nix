{ config, pkgs, inputs, ... }:

{
  imports = [
    ../shared/packages.nix    # Base packages for all users
    ../shared/modules         # Base configurations for all users
    ./packages.nix            # Additional user-specific packages
    ./modules                 # User-specific configuration overrides
  ];

  home = {
    username = "paper";
    homeDirectory = "/home/paper";
    stateVersion = "26.05";
  };

  programs.home-manager.enable = true;

  # Stylix theme
  stylix.targets = {
    fish.enable = true;
    vim.enable = true;
    gtk.enable = true;
    rofi.enable = false;
  };

  xdg.desktopEntries = {
    vesktop = {
      name = "Vesktop (Secured)";
      genericName = "Discord Client";
      exec = "vesktop %U";
      icon = "vesktop";
      categories = [ "Network" "Chat" "InstantMessaging" ];
      terminal = false;
      mimeType = [ "x-scheme-handler/discord" ];
    };
  };
}
