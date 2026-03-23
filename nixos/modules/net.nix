{ config, lib, pkgs, ... }:

{
  boot.kernel.sysctl."net.ipv4.ip_default_ttl" = 65;

  networking = {
    networkmanager = {
      enable = true;
      wifi.powersave = false; # stable connection > battery
    };

    firewall = {
      enable = true;
      allowedTCPPorts = [ ];
      allowedUDPPorts = [ ];
    };

    hosts = {
    "172.66.165.132" = ["api.zed.dev"];
    };
  };
}
