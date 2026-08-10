{ config, pkgs, ... }:




let
  secure-vesktop = pkgs.writeShellScriptBin "vesktop" ''
    chmod 666 /run/user/1000/''${WAYLAND_DISPLAY:-wayland-0}
    exec sudo ${pkgs.systemd}/bin/systemd-run \
      --description="Secure Vesktop (User: paper-dis)" \
      --property=BindPaths="/var/lib/paper-dis-vesktop:/var/lib/paper-dis-vesktop /run/user/1000/''${WAYLAND_DISPLAY}:/var/lib/paper-dis-vesktop/''${WAYLAND_DISPLAY} /run/user/1000/pulse:/run/user/1000/pulse /run/user/1000/bus:/var/lib/paper-dis-vesktop/bus" \
      --property=BindReadOnlyPaths=/home/paper:/home/paper \
      --uid=paper-dis \
      --gid=paper-dis \
      --setenv=HOME=/var/lib/paper-dis-vesktop \
      --setenv=XDG_RUNTIME_DIR=/var/lib/paper-dis-vesktop \
      --setenv=WAYLAND_DISPLAY=''${WAYLAND_DISPLAY:-wayland-0} \
      --setenv=DISPLAY=$DISPLAY \
      --setenv=PULSE_SERVER=unix:/run/user/1000/pulse/native \
      --setenv=DBUS_SESSION_BUS_ADDRESS=unix:path=/var/lib/paper-dis-vesktop/bus \
      --wait \
      ${pkgs.vesktop}/bin/vesktop --no-sandbox --ozone-platform=wayland "$@"
  '';
in
{
  home.packages = with pkgs; [
    # Network
    ayugram-desktop
    chromium
    qbittorrent
    secure-vesktop

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
