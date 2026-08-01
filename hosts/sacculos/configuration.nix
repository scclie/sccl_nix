{ config, lib, pkgs, inputs, ... }:
{
  imports = [
    ./hardware-configuration.nix
    ./gpu.nix
    ../../profiles/paper/user.nix
    ../../profiles/bootstrap/user.nix
  ];

  networking.hostName = "sacculos";

  sccl = {
    ui.enable = true;
    audio.enable = true;
    bluetooth.enable = true;
    net.enable = true;
    zapret.enable = true;
    flclashx.enable = true;
    playground.enable = true;
    nix-ld.enable = true;
    ui.wallpaperSha256 = "sha256-cqL194wcTxCKmSFf+z0BfyZlLAlFs8pnzAManlQbkjQ=";
  };

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    extraSpecialArgs = {
      inherit inputs;
      pkgs-unstable = inputs.nixpkgs-unstable.legacyPackages.${pkgs.system};
      niriKbLayout = "colemak_caws,rulemak_caws";
      niriKbOptions = "caps:backspace,grp:rwin_toggle,lv3:ralt_switch";
      niriOutput = ''
        output "DP-2" {
            mode "2560x1440@500"
            scale 1.0
        }
      '';
      niriExtraBinds = "";
      niriExtraSpawn = "";
    };
  } // (if config.sccl.bootstrap
    then { users.bootstrap = import ../../profiles/bootstrap/home.nix; }
    else { users.paper = import ../../profiles/paper/home.nix; });

  nixpkgs.config.permittedInsecurePackages = [
    "python3.13-ecdsa-0.19.2"
  ];

  system.stateVersion = "26.05";
}
