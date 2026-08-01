{ config, lib, inputs, ... }:
let
  cfg = config.sccl;
in {
  options = {
    sccl.ui.enable = lib.mkEnableOption "Stylix + greetd display manager";
    sccl.audio.enable = lib.mkEnableOption "PipeWire audio";
    sccl.bluetooth.enable = lib.mkEnableOption "Bluetooth + Blueman";
    sccl.net.enable = lib.mkEnableOption "NetworkManager + proxy + firewall";
    sccl.automount.enable = lib.mkEnableOption "udisks2 USB automount";
    sccl.secrets.enable = lib.mkEnableOption "sops-nix secrets";
    sccl.zapret.enable = lib.mkEnableOption "zapret DPI bypass";
    sccl.flclashx.enable = lib.mkEnableOption "FlClashX proxy GUI";
    sccl.playground.enable = lib.mkEnableOption "Docker + dev tools";
    sccl.chaotic.enable = lib.mkEnableOption "chaotic-nyx repo";
    sccl.nix-ld.enable = lib.mkEnableOption "nix-ld for binaries";
    sccl.bootstrap = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Use bootstrap profile (minimal) instead of full user profile";
    };
  };

  imports =
    [
      ./boot.nix
      ./nix.nix
      ./env.nix
      ./keyboard.nix
      ./timezone.nix
    ]
    ++ lib.optionals cfg.ui.enable [
      ./display-manager.nix
      ./stylix.nix
      inputs.stylix.nixosModules.stylix
    ]
    ++ lib.optionals cfg.audio.enable [
      ./audio.nix
      ./xdg-portal.nix
    ]
    ++ lib.optionals cfg.bluetooth.enable [ ./bluetooth.nix ]
    ++ lib.optionals cfg.net.enable [ ./net.nix ]
    ++ lib.optionals cfg.automount.enable [ ./automount.nix ]
    ++ lib.optionals cfg.secrets.enable [ ./secrets.nix ]
    ++ lib.optionals cfg.zapret.enable [ ./zapret.nix ]
    ++ lib.optionals cfg.flclashx.enable [ ./flclashx.nix ]
    ++ lib.optionals cfg.playground.enable [ ./playground.nix ]
    ++ lib.optionals cfg.nix-ld.enable [ ./nix-ld.nix ];

  config = lib.mkMerge [
    {
      imports = [
        inputs.disko.nixosModules.disko
        inputs.home-manager.nixosModules.home-manager
      ];
    }
    (lib.mkIf cfg.chaotic.enable {
      imports = [ inputs.chaotic.nixosModules.default ];
    })
  ];
}
