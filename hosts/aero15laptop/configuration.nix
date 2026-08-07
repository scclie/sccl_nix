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
    secrets.enable = true;
    mihomo = {
      enable = true;
      fakeHwid = "B8A7E6D5C4B3";
    };
    nix-ld.enable = true;
  };

  security.sudo.extraRules = [{
    users = ["paper"];
    commands = [{
      command = "/home/paper/.local/bin/toggle-builtin-kb";
      options = ["NOPASSWD"];
    }];
  }];

  services.keyd = {
    enable = true;
    keyboards = {
      builtin = {
        ids = [ "HOLTEK USB-HID Keyboard" ];
        settings = {
          main = {
            # Number row (DH Wide angle mod)
            "7" = "backslash";
            "8" = "7";
            "9" = "8";
            "0" = "9";
            minus = "0";
            equal = "minus";
            backslash = "equal";

            # Top row
            e = "f";
            r = "p";
            t = "b";
            y = "rightbrace";
            u = "j";
            i = "l";
            o = "u";
            p = "y";
            leftbrace = "apostrophe";
            rightbrace = "semicolon";

            # Home row
            s = "r";
            d = "s";
            f = "t";
            h = "leftbrace";
            j = "m";
            k = "n";
            l = "e";
            semicolon = "i";
            apostrophe = "o";

            # Bottom row (Angle mod)
            z = "x";
            x = "c";
            c = "d";
            b = "z";
            n = "slash";
            m = "k";
            comma = "h";
            period = "comma";
            slash = "period";

            # RCtrl → RWIN for niri XKB toggle + keyd layer toggle
            rightctrl = "rightmeta";
            f12 = "layer(ru)";
          };

          ru = {
            # Russian overrides (Y/H/]/\\ swap for rulemak_caws compatibility)
            y = "leftbrace";
            h = "rightbrace";
            rightbrace = "fk13";
            backslash = "fk14";
            f12 = "layer(main)";
          };
        };
      };
    };
  };

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    extraSpecialArgs = {
      inherit inputs;
      hasSecrets = config.sccl.secrets.enable;
      pkgs-unstable = inputs.nixpkgs-unstable.legacyPackages.${pkgs.system};
      niriKbLayout = "colemak_caws,rulemak_caws";
      niriKbOptions = "caps:backspace,grp:rwin_toggle,lv3:ralt_switch";
      niriOutput = ''
        output "eDP-1" {
            mode "1920x1080@144"
            scale 1.0
        }
      '';
      niriBuiltinKbIdentifier = "1:1:AT_Translated_Set_2_keyboard";
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
