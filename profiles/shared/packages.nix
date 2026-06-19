{ config, pkgs, ... }:

{
  home.packages = with pkgs; [
    # CLI Tools
    # Note: btop, bat, eza are configured via modules
    fastfetch
    ripgrep
    fd
    fzf
    zoxide
    killall

    # GUI Applications
    xfce.thunar
    xfce.thunar-archive-plugin
    xfce.thunar-volman
    xfce.tumbler
    file-roller

    # Media
    vlc
    mpv
    evince
    # Note: zathura is configured via module

    # System Utilities
    grim
    slurp
    wl-clipboard
    pavucontrol
    appimage-run
    gparted

    # Network
    firefox

    # Development
    nixd
    gh

    # Themes & Icons
    nordic
    papirus-icon-theme
    rose-pine-hyprcursor

    # Fonts
    jetbrains-mono
    noto-fonts
    noto-fonts-color-emoji
    twemoji-color-font
    font-awesome
    powerline-fonts
    powerline-symbols
    nerd-fonts.symbols-only
  ];
}
