{ config, lib, pkgs, ... }:

let
  cfg = config.sccl.flclashx;

  flclashxDefault = pkgs.appimageTools.wrapType2 rec {
    pname = "flclashx";
    version = "0.3.2";

    src = pkgs.fetchurl {
      # https://github.com/pluralplay/FlClashX/releases/tag/v0.3.2
      url = "https://github.com/pluralplay/FlClashX/releases/download/v0.3.2/FlClashX-linux-amd64.AppImage";
      hash = "sha256-RbL1M6WKsUoxt83kDmkjoWs2voIBzp9P4hbSn5MDBow=";
    };

    extraPkgs = pkgs: with pkgs; [
      libepoxy
    ];

    extraInstallCommands = ''
      mkdir -p $out/share/applications
      cat > $out/share/applications/flclashx.desktop <<'EOF'
      [Desktop Entry]
      Type=Application
      Name=FlClashX
      Exec=flclashx
      Categories=Network;
      EOF
    '';

    meta = with lib; {
      description = "FlClashX (FlClash fork) proxy client";
      homepage = "https://github.com/pluralplay/FlClashX";
      platforms = platforms.linux;
      mainProgram = "flclashx";
    };
  };
in
{
  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ flclashxDefault ];
  };
}
