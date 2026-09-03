{ config, lib, pkgs, ... }:
let
  cfg = config.sccl.minecraft;
in {
  options.sccl.minecraft = {
    enable = lib.mkEnableOption "Minecraft server (stub — modpack build pending)";
  };

  config = lib.mkIf cfg.enable {
    # Firewall ports for game servers
    networking.firewall.allowedTCPPortRanges = [
      { from = 25565; to = 25590; }
    ];
    networking.firewall.allowedUDPPortRanges = [
      { from = 25565; to = 25590; }
    ];

    # Dataset /tank/data/minecraft + /tank/minecraft already created in disko.nix

    # TODO: Pterodactyl panel + wings deployment when modpack build is ready
    # - panel + MariaDB + Redis containers
    # - wings on host with docker.sock
    # - mc.sccl.cc (wg-only admin), game ports public
  };
}
