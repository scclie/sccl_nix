{ config, pkgs, ... }:




let
  secure-vesktop = pkgs.writeShellScriptBin "vesktop" ''
    ${pkgs.xorg.xhost}/bin/xhost +SI:localuser:paper-dis > /dev/null 2>&1 || true

    exec sudo ${pkgs.systemd}/bin/systemd-run \
      --description="Secure Vesktop (User: paper-dis)" \
      --property=BindPaths=/var/lib/paper-dis-vesktop:/var/lib/paper-dis-vesktop \
      --property=BindReadOnlyPaths=/home/paper:/home/paper \
      --property=BindPaths=/run/user/1000/pulse:/run/user/1000/pulse \
      --uid=paper-dis \
      --gid=paper-dis \
      --setenv=HOME=/var/lib/paper-dis-vesktop \
      --setenv=XDG_RUNTIME_DIR=/run/user/1000 \
      --setenv=WAYLAND_DISPLAY=''${WAYLAND_DISPLAY:-wayland-0} \
      --setenv=DISPLAY=$DISPLAY \
      --setenv=PULSE_SERVER=unix:/run/user/1000/pulse/native \
      --wait \
      ${pkgs.vesktop}/bin/vesktop --no-sandbox "$@"
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
