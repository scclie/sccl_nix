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
  users.users.root.initialHashedPassword = "!";

  sccl = {
    ui.enable = true;
    ui.wallpaperSha256 = "sha256-cqL194wcTxCKmSFf+z0BfyZlLAlFs8pnzAManlQbkjQ=";
    audio.enable = true;
    bluetooth.enable = true;
    net.enable = true;
    secrets = {
      enable = true;
      scopes = [ "personal" ];
    };
    mihomo = {
      enable = true;
      fakeHwid = "B8A7E6D5C4B3";
    };
    nix-ld.enable = true;
  };

  ###########################  ###########################  ###########################  ###########################  ###########################
  # WIREGUARD
  sops.secrets = lib.genAttrs [
    "wireguard/laeradr-endpoint"
    "wireguard/laeradr-public-key"
    "wireguard/aero15-private-key"
  ] (_: {
    sopsFile = ../../secrets/personal.yaml;
    mode = "0400";
  });

  sops.templates."wireguard-laeradr.conf" = {
    mode = "0400";
    content = ''
      [Interface]
      Address = 10.100.0.2/32
      PrivateKey = ${config.sops.placeholder."wireguard/aero15-private-key"}

      [Peer]
      PublicKey = ${config.sops.placeholder."wireguard/laeradr-public-key"}
      Endpoint = ${config.sops.placeholder."wireguard/laeradr-endpoint"}
      AllowedIPs = 10.100.0.1/32
      PersistentKeepalive = 25
    '';
  };

  networking.wg-quick.interfaces.laeradr = {
    autostart = false;
    configFile = config.sops.templates."wireguard-laeradr.conf".path;
  };

  ###########################  ###########################  ###########################  ###########################  ###########################

  security.sudo.extraRules = [{
    users = ["paper"];
    commands = [{
      command = toString config.home-manager.users.paper.home.file.".local/bin/toggle-builtin-kb".source;
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
            # number row (curl angle wide mods)
            "7" = "backslash";
            "8" = "7";
            "9" = "8";
            "0" = "9";
            minus = "0";
            equal = "minus";
            backslash = "equal";

            # top row
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

            # home row
            s = "r";
            d = "s";
            f = "t";
            h = "leftbrace";
            j = "m";
            k = "n";
            l = "e";
            semicolon = "i";
            apostrophe = "o";

            # bottom row (angle mod)
            z = "x";
            x = "c";
            c = "d";
            b = "z";
            n = "slash";
            m = "k";
            comma = "h";
            period = "comma";
            slash = "period";

            rightctrl = "rightmeta";
            f12 = "layer(ru)";
          };

          ru = {
            # rus overrides
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
      mailPasswordPath = config.sops.secrets."mail/app-password".path;
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
