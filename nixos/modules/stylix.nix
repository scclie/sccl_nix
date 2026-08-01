{ config, lib, pkgs, ... }:
let cfg = config.sccl.ui;
in {
  options.sccl.ui.wallpaper = lib.mkOption {
    type = lib.types.package;
    description = "Stylix wallpaper image";
  };
  options.sccl.ui.wallpaperSha256 = lib.mkOption {
    type = lib.types.str;
    description = "SHA256 for wallpaper fetchurl";
  };

  config = lib.mkIf cfg.enable {
    stylix = {
      enable = true;
      base16Scheme = "${pkgs.base16-schemes}/share/themes/nord.yaml";
      image = pkgs.fetchurl {
        url = "https://github.com/OulipianSummer/nixos-pattern-nord-wallpapers/blob/master/jpgs/nix-d-nord-purple.jpg?raw=true";
        sha256 = cfg.wallpaperSha256;
      };
      fonts = {
        monospace = {
          package = pkgs.nerd-fonts.caskaydia-cove;
          name = "CaskaydiaCove Nerd Font Mono";
        };
        sizes = {
          applications = 10;
          terminal = 11;
          desktop = 10;
          popups = 10;
        };
      };
    };
  };
}
