{ config, pkgs, ... }:

{
  home.packages = with pkgs; [
    # Network
    ayugram-desktop
    chromium
    qbittorrent
    # Crypto
    electrum
    electrum-ltc

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
    kicad
    opencode

    # Gaming
    steam
    protonplus
    steam-run
    gamemode
    bottles
    modrinth-app
    faugus-launcher
    # hmcl
    prismlauncher

    # Creative Tools
    # kdePackages.kdenlive
    krita
    aseprite
    blender
    wf-recorder
    orca-slicer

    # Audio
    easyeffects
    audacity
    sonic-visualiser
    x42-plugins

    # Office
    libreoffice-fresh

  ];
}
