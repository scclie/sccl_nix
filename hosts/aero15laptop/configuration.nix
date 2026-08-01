{ config, lib, pkgs, inputs, ... }:
{
  disabledModules = [ ../../nixos/modules/keyboard.nix ];

  imports = [
    ./hardware-configuration.nix
    ./gpu.nix
    ../../profiles/paper/user.nix
  ];

  networking.hostName = "aero15laptop";
  services.openssh.enable = true;
  users.users.root.initialPassword = "root";

  sccl = {
    ui.enable = true;
    ui.wallpaperSha256 = "sha256-cqL194wcTxCKmSFf+z0BfyZlLAlFs8pnzAManlQbkjQ=";
    audio.enable = true;
    bluetooth.enable = true;
    net.enable = true;
    flclashx.enable = true;
    nix-ld.enable = true;
  };

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    users.paper = import ../../profiles/paper/home.nix;
    extraSpecialArgs = {
      inherit inputs;
      pkgs-unstable = inputs.nixpkgs-unstable.legacyPackages.${pkgs.system};
      niriKbLayout = "colemak_caws,rulemak_caws";
      niriKbOptions = "caps:backspace,grp:rwin_toggle,lv3:ralt_switch";
      niriOutput = ''
        output "eDP-1" {
            mode "1920x1080@144"
            scale 1.0
        }
      '';
      niriExtraBinds = "";
      niriExtraSpawn = "";
    };
  };

  nixpkgs.config.permittedInsecurePackages = [
    "python3.13-ecdsa-0.19.2"
  ];

  system.stateVersion = "26.05";
}
