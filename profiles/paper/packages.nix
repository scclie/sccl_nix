{ config, pkgs, ... }:




let
  secure-vesktop = pkgs.writeShellScriptBin "vesktop" ''
    exec sudo ${pkgs.systemd}/bin/systemd-run \
      --description="Secure Vesktop (User: paper-dis)" \
      --property=BindPaths="/var/lib/paper-dis-vesktop:/var/lib/paper-dis-vesktop /run/user/1000/''${WAYLAND_DISPLAY}:/run/user/1000/''${WAYLAND_DISPLAY} /run/user/1000/pulse:/run/user/1000/pulse /run/user/1000/bus:/var/lib/paper-dis-vesktop/bus" \
      --property=BindReadOnlyPaths=/home/paper:/home/paper \
      --uid=paper-dis \
      --gid=paper-dis \
      --setenv=HOME=/var/lib/paper-dis-vesktop \
      --setenv=XDG_RUNTIME_DIR=/var/lib/paper-dis-vesktop \
      --setenv=WAYLAND_DISPLAY=''${WAYLAND_DISPLAY:-wayland-0} \
      --setenv=DISPLAY=$DISPLAY \
      --setenv=PULSE_SERVER=unix:/run/user/1000/pulse/native \
      --setenv=DBUS_SESSION_BUS_ADDRESS=unix:path=/var/lib/paper-dis-vesktop/bus \
      --setenv=http_proxy=http://127.0.0.1:7890 \
      --setenv=https_proxy=http://127.0.0.1:7890 \
      --setenv=all_proxy=http://127.0.0.1:7890 \
      --setenv=no_proxy=127.0.0.1,localhost,internal.domain,127.0.0.0/8,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16 \
      --setenv=HTTP_PROXY=http://127.0.0.1:7890 \
      --setenv=HTTPS_PROXY=http://127.0.0.1:7890 \
      --setenv=ALL_PROXY=http://127.0.0.1:7890 \
      --setenv=NO_PROXY=127.0.0.1,localhost,internal.domain,127.0.0.0/8,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16 \
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
