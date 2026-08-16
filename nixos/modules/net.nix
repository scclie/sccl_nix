{ config, lib, pkgs, ... }:

# fck putin fck putin fck putin fck putin fck putin fck putin fck putin fck putin
# putin fck putin fck putin fck putin fck putin fck putin fck putin fck putin fck
# ...and rkn,
# i fckng need to keep two fckn services on in the system,
# just so that the fucking internet works for me.

{
  boot.kernel.sysctl."net.ipv4.ip_default_ttl" = 65;

  networking = {
    # Proxy is now handled by mihomo TUN at network level.
    # No HTTP proxy env vars needed.

    networkmanager = {
      enable = true;
      wifi.powersave = false; # stable connection > battery
      dns = "none";           # mihomo serves DNS on 127.0.0.1:53
    };

    nameservers = [ "127.0.0.1" ];

    firewall = {
      enable = true;
      allowedTCPPorts = [ 7890 ];  # mihomo mixed-port for local proxy access
      allowedUDPPorts = [ ];
    };

    hosts = {
      "172.66.165.132" = ["api.zed.dev"];
    };
  };
}
