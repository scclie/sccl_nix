{ config, lib, pkgs, ... }:

{
  boot.kernel.sysctl."net.ipv4.ip_default_ttl" = 65;

  networking = {
    # proxy all fkn rkn fuck putin
    proxy = {
      default = "http://127.0.0.1:7890";
      noProxy = "127.0.0.1,localhost,internal.domain,127.0.0.0/8,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16"; # ignore proxy for RFC 1918
    };

    networkmanager = {
      enable = true;
      wifi.powersave = false; # stable connection > battery
    };

    firewall = {
      enable = true;
      allowedTCPPorts = [ 7890 ];  # FlClashX proxy Docker
      allowedUDPPorts = [ ];
    };

    hosts = {
      "172.66.165.132" = ["api.zed.dev"];
    };
  };
}
