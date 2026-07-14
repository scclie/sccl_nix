{ config, pkgs, lib, ... }:

{
  stylix.targets.alacritty.enable = false;

  programs.alacritty = {
    enable = true;
    
    settings = {
      window = {
        padding = {
          x = lib.mkForce 10;
          y = lib.mkForce 10;
        };
        opacity = lib.mkForce 0.95;
      };
      
      font = {
        size = lib.mkForce 11.0;
        normal = {
          family = lib.mkForce "CaskaydiaCove Nerd Font";
          style = lib.mkForce "Regular";
        };
      };
      
      cursor.style = lib.mkForce "Block";
      
      keyboard.bindings = [
        { key = "V"; mods = "Control|Shift"; action = "Paste"; }
        { key = "C"; mods = "Control|Shift"; action = "Copy"; }
      ];
    };
  };
  
  home.packages = with pkgs; [
    nerd-fonts.caskaydia-cove
  ];
}
