{ config, lib, pkgs, inputs, ... }:
{
  imports = [
    ./hardware-configuration.nix
    ./gpu.nix
    ./local-packages.nix
    ../../profiles/paper/user.nix
    ../../profiles/bootstrap/user.nix
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
    secrets.enable = true;
    nix-ld.enable = true;
  };

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    extraSpecialArgs = {
      inherit inputs;
      hasSecrets = config.sccl.secrets.enable;
      pkgs-unstable = inputs.nixpkgs-unstable.legacyPackages.${pkgs.system};
      niriKbLayout = "colemak_dh_wide_en,colemak_dh_wide_ru";
      niriKbOptions = "caps:backspace,grp:rctrl_toggle";
      niriOutput = ''
        output "eDP-1" {
            mode "1920x1080@144"
            scale 1.0
        }
      '';
      niriExtraBinds = "";
      niriExtraSpawn = "";
    };
    users.paper = import ../../profiles/paper/home.nix;
  };

  nixpkgs.config.permittedInsecurePackages = [
    "python3.13-ecdsa-0.19.2"
  ];

  system.stateVersion = "26.05";
}
