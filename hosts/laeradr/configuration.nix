{ config, lib, pkgs, inputs, ... }:
{
  imports = [
    ./hardware-configuration.nix
    ./local-packages.nix
    ../../profiles/server/user.nix
  ];

  networking.hostName = "laeradr";

  sccl = {
    boot.cachyos = false;
    secrets = {
      enable = true;
      user = "heimdall";
      scopes = [ "infra" "db" "apps" ];
    };
    server = {
      enable = true;
      domain = "sccl.cc";
      acmeEmail = "admin@sccl.cc";
    };
    dns = {
      enable = true;
      zone = "sccl.cc";
      publicIp = "REDACTED";
    };
    wireguard = {
      enable = true;
      peers = [
        # { publicKey = "..."; allowedIPs = [ "10.100.0.2/32" ]; }
      ];
    };
    databases = {
      enable = true;
    };
    sftpgo = {
      enable = true;
    };
    forgejo = {
      enable = true;
    };
    vaultwarden = {
      enable = true;
    };
    mail = {
      enable = true;
    };
    monitoring = {
      enable = true;
    };
    status = {
      enable = true;
      endpoints = [
        { name = "main website"; group = "apps"; url = "https://sccl.cc"; interval = "5m"; }
        { name = "sftpgo"; group = "services"; url = "https://files.sccl.cc"; interval = "5m"; }
        { name = "forgejo"; group = "services"; url = "https://git.sccl.cc"; interval = "5m"; }
        { name = "vaultwarden"; group = "services"; url = "https://pass.sccl.cc"; interval = "5m"; }
        { name = "maddy"; group = "services"; url = "https://mail.sccl.cc"; interval = "5m"; }
        { name = "prometheus"; group = "monitoring"; url = "https://prometheus.sccl.cc/-/healthy"; interval = "5m"; }
        { name = "grafana"; group = "monitoring"; url = "https://grafana.sccl.cc/api/health"; interval = "5m"; }
        { name = "loki"; group = "monitoring"; url = "https://loki.sccl.cc/ready"; interval = "5m"; }
        { name = "alertmanager"; group = "monitoring"; url = "https://alertmanager.sccl.cc/-/healthy"; interval = "5m"; }
      ];
    };
    backup = {
      enable = true;
      resticRepository = "s3:s3.amazonaws.com/backups-sccl";
    };
    proxy = {
      enable = true;
      sites = {
        git = { upstream = "http://10.69.0.10:3000"; };
        # pass / pass-api are registered by the vaultwarden module itself
      };
    };
  };

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    users.heimdall = import ../../profiles/server/home.nix;
  };

  system.stateVersion = "26.05";
}
