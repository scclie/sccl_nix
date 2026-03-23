{ config, pkgs, ... }:

{
  home.packages = with pkgs; [
    # Network
    ayugram-desktop
    chromium
    qbittorrent
    vesktop

    # Development
    lmstudio
    lazygit
    rustc
    cargo
    gcc
    obsidian
    kiro
    vial
    python315
    nodejs_24

    # Gaming
    steam
    protonplus
    steam-run
    bottles
    modrinth-app
    faugus-launcher
    # hmcl
    lunar-client

    # Creative Tools
    kdePackages.kdenlive
    krita
    aseprite
    blender
    audacity

    # Audio
    easyeffects

    # Office
    libreoffice-fresh

  ];
}
