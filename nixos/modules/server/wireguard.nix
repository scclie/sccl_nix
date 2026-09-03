{ config, lib, pkgs, ... }:
let
  cfg = config.sccl.wireguard;
  wgInterface = "wg0";
in {
  options.sccl.wireguard = {
    enable = lib.mkEnableOption "WireGuard VPN server";
    port = lib.mkOption {
      type = lib.types.port;
      default = 51820;
      description = "WireGuard listen port";
    };
    subnet = lib.mkOption {
      type = lib.types.str;
      default = "10.100.0";
      description = "WireGuard IPv4 subnet (first three octets, e.g. 10.100.0)";
    };
    privateKeyFile = lib.mkOption {
      type = lib.types.path;
      default = "/run/secrets/wireguard/private-key";
      description = "Path to WireGuard private key file";
    };
    peers = lib.mkOption {
      type = lib.types.listOf (lib.types.submodule {
        options = {
          publicKey = lib.mkOption { type = lib.types.str; description = "Peer public key"; };
          allowedIPs = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [];
            description = "IP ranges routed to this peer";
          };
          presharedKeyFile = lib.mkOption {
            type = lib.types.nullOr lib.types.path;
            default = null;
            description = "Optional preshared key file";
          };
        };
      });
      default = [];
      description = "List of WireGuard peers";
    };
    serverAddress = lib.mkOption {
      type = lib.types.str;
      default = "${cfg.subnet}.1";
      internal = true;
    };
  };

  config = lib.mkIf cfg.enable {
    # Private key from sops
    sops.secrets."wireguard/private-key" = {
      sopsFile = ../../../secrets/infra.yaml;
    };

    networking.wireguard = {
      interfaces = {
        ${wgInterface} = {
          listenPort = cfg.port;
          privateKeyFile = cfg.privateKeyFile;
          ips = [ "${cfg.subnet}.1/24" ];
          peers = map (peer: {
            publicKey = peer.publicKey;
            allowedIPs = peer.allowedIPs;
            presharedKeyFile = peer.presharedKeyFile;
          }) cfg.peers;
        };
      };
    };

    # WireGuard is built-in on kernels 5.6+, only add extra module if available
    boot.extraModulePackages = lib.optionals (config.boot.kernelPackages.wireguard != null) [ config.boot.kernelPackages.wireguard ];
    boot.kernelModules = [ "wireguard" ];
  };
}
