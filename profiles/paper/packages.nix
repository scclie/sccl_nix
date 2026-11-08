{ pkgs, ... }:

{
  home.packages = with pkgs; [
    # Network
    ayugram-desktop
    chromium
    lagrange
    qbittorrent
    discordo
    #vesktop
    mumble
    fluffychat
    cinny
    #nheko
    #commet-chat

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
    vial
    python315
    nodejs_24
    kicad
    esptool
    platformio
    usbutils

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
    pixieditor

    # Audio
    easyeffects
    audacity
    sonic-visualiser
    x42-plugins

    # Office
    libreoffice-fresh

  ];
}
