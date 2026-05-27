{ config, lib, pkgs, ... }:

{
  home.sessionVariables = {
    FREI0R_PATH = "${pkgs.frei0r}/lib/frei0r-1";
    LADSPA_PATH = "${pkgs.ladspaPlugins}/lib/ladspa";
    MLT_PATH = "${pkgs.mlt}/lib/mlt";
  };

  home.packages = with pkgs; [
    kdePackages.kdenlive
    frei0r
    ladspaPlugins
    mlt
    ffmpeg-full
  ];
}
