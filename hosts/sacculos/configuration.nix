{ config, lib, pkgs, inputs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ./local-packages.nix
    ./disko.nix
    ../../nixos/modules
    ../../profiles/paper/user.nix
  ];

  networking.hostName = "sacculos";

  # Home-manager configuration
  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    users.paper = import ../../profiles/paper/home.nix;

    extraSpecialArgs = {
      inherit inputs;
      pkgs-unstable = inputs.nixpkgs-unstable.legacyPackages.${pkgs.system};
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
  };

    programs.flclashx.enable = true;

    programs.nix-ld.enable = true; # runs proprietary garbage
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

  system.stateVersion = "26.05";
}
