{ config, lib, pkgs, ... }:
let cfg = config.sccl.nix-ld;
in {
  config = lib.mkIf cfg.enable {
    programs.nix-ld.enable = true;
    programs.nix-ld.libraries = with pkgs; [
      gcc.cc.lib glibc openssl zlib
      qt6.qtbase qt6.qtwebengine qt6.qtdeclarative
      gtk3 gdk-pixbuf webkitgtk_4_1 glib
      libGL libglvnd alsa-lib libpulseaudio dbus
      fontconfig freetype pango cairo
      libtiff libjpeg giflib libpng expat
    ];
  };
}
