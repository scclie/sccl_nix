{ config, lib, pkgs, inputs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ./local-packages.nix
    ./disko.nix

    # nixos modules (laptop: nvidia instead of amd-gpu)
    ../../nixos/modules/boot.nix
    ../../nixos/modules/nix.nix
    ../../nixos/modules/net.nix
    ../../nixos/modules/timezone.nix
    ../../nixos/modules/env.nix
    ../../nixos/modules/audio.nix
    ../../nixos/modules/bluetooth.nix
    ../../nixos/modules/kernel.nix
    ../../nixos/modules/keyboard-colemak.nix
    ../../nixos/modules/nvidia-gpu.nix
    ../../nixos/modules/xdg-portal.nix
    ../../nixos/modules/display-manager.nix
    ../../nixos/modules/flclashx.nix
    ../../nixos/modules/playground.nix

    ../../profiles/paper/user.nix
  ];

  networking.hostName = "aero15laptop";
  services.openssh.enable = true;
  users.users.root.initialPassword = "root";

  # Home-manager configuration
  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    users.paper = import ../../profiles/paper/home.nix;

    extraSpecialArgs = {
      inherit inputs;
      pkgs-unstable = inputs.nixpkgs-unstable.legacyPackages.${pkgs.system};
      niriKbLayout = "colemak_dh,rulemak";
      niriKbOptions = "caps:backspace,grp:win_space_toggle,lv3:ralt_alt";
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

  # Stylix global theme (Nord)
  stylix = {
    enable = true;
    base16Scheme = "${pkgs.base16-schemes}/share/themes/nord.yaml";
    image = pkgs.fetchurl {
      url = "https://github.com/OulipianSummer/nixos-pattern-nord-wallpapers/blob/master/jpgs/nix-d-nord-purple.jpg?raw=true";
      sha256 = "sha256-cqL194wcTxCKmSFf+z0BfyZlLAlFs8pnzAManlQbkjQ=";
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

    programs.flclashx.enable = true;

    programs.nix-ld.enable = true;
    programs.nix-ld.libraries = with pkgs; [
        gcc.cc.lib
        glibc
        openssl
        zlib
        qt6.qtbase
        qt6.qtwebengine
        qt6.qtdeclarative
        gtk3
        gdk-pixbuf
        webkitgtk_4_1
        glib
        libGL
        libglvnd
        alsa-lib
        libpulseaudio
        dbus
        fontconfig
        freetype
        pango
        cairo
        libtiff
        libjpeg
        giflib
        libpng
        expat
    ];

  nixpkgs.config.permittedInsecurePackages = [
    "python3.13-ecdsa-0.19.2"
  ];

  system.stateVersion = "26.05";
}
