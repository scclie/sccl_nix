{ config, pkgs, ... }:

let
  secure-vesktop = pkgs.writeShellScriptBin "vesktop" ''
    # transient-service systemd from 'paper-dis' user.
    systemd-run \
      --user \
      --uid=paper-dis \
      --gid=paper-dis \
      --property=BindPaths=/var/lib/paper-dis-vesktop:/var/lib/paper-dis-vesktop \
      --setenv=HOME=/var/lib/paper-dis-vesktop \
      --setenv=XDG_RUNTIME_DIR=/run/user/1000 \
      --setenv=WAYLAND_DISPLAY=$WAYLAND_DISPLAY \
      --setenv=DISPLAY=$DISPLAY \
      --setenv=PULSE_SERVER=unix:/run/user/1000/pulse/native \
      ${pkgs.vesktop}/bin/vesktop "$@"
  '';
in
{
  home.packages = with pkgs; [
    # Network
    ayugram-desktop
    chromium
    qbittorrent
    secure-vesktop

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
