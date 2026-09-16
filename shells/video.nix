{ pkgs }:

let
  pkgs' = import pkgs.path {
    inherit (pkgs) system;
    config.permittedInsecurePackages = [ "electron-39.8.10" ];
  };
in
pkgs'.mkShell {
  packages = with pkgs'; [
    ffmpeg
losslesscut
  ];

  shellHook = ''
    echo "video shell - ffmpeg + lossless-cut"
    echo "GUI:  lossless-cut"
    echo "CLI:  ffmpeg"
  '';
}
