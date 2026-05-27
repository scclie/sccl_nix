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
    kicad

    # Gaming
    steam
    protonplus
    steam-run
    gamemode
    bottles
    modrinth-app
    faugus-launcher
    # hmcl
    lunar-client
    gdlauncher-carbon

    # Creative Tools
    # kdePackages.kdenlive
    krita
    aseprite
    blender
    audacity
    wf-recorder
    orca-slicer

    # Audio
    easyeffects

    # Office
    libreoffice-fresh

  ];
}
