{ ... }:

{
  imports = [
    ./cli.nix
    # GUI modules
    ./alacritty.nix
    ./zathura.nix
    ./gtk.nix
    ./hyprland.nix
    ./niri.nix
    ./waybar.nix
    ./fuzzel.nix
    ./rofi.nix
    ./cursor.nix
    ./zed-editor.nix
    ./obs.nix
    ./kdenlive.nix
  ];
}
