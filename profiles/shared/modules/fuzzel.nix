{ config, lib, pkgs, ... }:

{
  programs.fuzzel = {
    enable = true;
    
    settings = {
      main = {
        font = lib.mkForce "CaskaydiaCove Nerd Font:size=13";
        terminal = lib.mkForce "alacritty";
        prompt = lib.mkForce "❯ ";
        icon-theme = lib.mkForce "Nordzy-dark";
        fields = lib.mkForce "name,generic,comment,categories,filename";
        width = lib.mkForce 40;
        horizontal-pad = lib.mkForce 20;
        vertical-pad = lib.mkForce 10;
        inner-pad = lib.mkForce 10;
      };

      colors = {
        # Nord color palette - using mkForce to override Stylix settings
        background = lib.mkForce "2e3440dd";  # nord0 with transparency
        text = lib.mkForce "d8dee9ff";        # nord4
        match = lib.mkForce "88c0d0ff";       # nord8
        selection = lib.mkForce "81a1c1ff";   # nord9
        selection-text = lib.mkForce "2e3440ff";  # nord0
        border = lib.mkForce "81a1c1ff";      # nord9
      };

      border = {
        width = lib.mkForce 2;
        radius = lib.mkForce 10;
      };

      dmenu = {
        mode = lib.mkForce "text";
      };
    };
  };
}
