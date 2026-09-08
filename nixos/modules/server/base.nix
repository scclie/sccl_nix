{ config, lib, pkgs, ... }:
let
  cfg = config.sccl.server;
in {
  options.sccl.server = {
    enable = lib.mkEnableOption "headless NixOS server base";
    domain = lib.mkOption {
      type = lib.types.str;
      default = "sccl.cc";
      description = "Primary domain for the server";
    };
    hostIp = lib.mkOption {
      type = lib.types.str;
      default = "192.168.0.10";
      description = "Server IP (assigned via router DHCP reservation by MAC)";
    };
    acmeEmail = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = "Email for ACME/Let's Encrypt registration";
    };
  };

  config = lib.mkIf cfg.enable {
    # Headless tuning
    boot.loader.grub.enable = lib.mkForce false;
    boot.loader.systemd-boot.enable = true;
    boot.zfs.forceImportRoot = true; # force import root pool on first boot (new disk)

    # Networking
    networking = {
      useDHCP = true;
      hostId = "1f0b2328"; # from /etc/machine-id on laeradr; ZFS pool import requires this
      nameservers = [ "1.1.1.1" "8.8.8.8" ];

      # br-svc bridge for containers
      bridges.br-svc = {
        interfaces = [];
      };
      interfaces.br-svc.ipv4.addresses = [{
        address = "10.69.0.1";
        prefixLength = 24;
      }];

      # NAT containers on br-svc (10.69.0.0/24) to reach the internet.
      # No external SSH port: Forgejo SSH is disabled (access via wg).
      nat = {
        enable = true;
        internalInterfaces = [ "br-svc" ];
        externalInterface = "enp4s0";
      };

      firewall = {
        enable = true;
        allowedTCPPorts = [ 22 80 443 25 465 587 993 8448 ];
        allowedUDPPorts = [ 51820 ];
        allowedTCPPortRanges = [ { from = 25565; to = 25590; } ];
        allowedUDPPortRanges = [ { from = 25565; to = 25590; } ];
      };
    };

    # SSH hardening
    services.openssh = {
      enable = true;
      settings = {
        PasswordAuthentication = false;
        PermitRootLogin = "prohibit-password";
        X11Forwarding = false;
        AllowTcpForwarding = "no";
      };
      # Bind admin SSH only to LAN + WireGuard. No public SSH: git traffic
      # goes over WireGuard + HTTPS (Forgejo SSH is disabled).
      listenAddresses = [
        { addr = "192.168.0.10"; }
        { addr = "10.100.0.1"; }
      ];
    };

    # Ensure static addresses (enp4s0, wg0) exist before sshd binds them.
    systemd.services.sshd = {
      wants = [ "network-online.target" ];
      after = [ "network-online.target" ];
    };

    # SSH access
    users.users.root.openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILREBz4a7g2D+DfvOTHYn+yGiYnhBAU4eMnF6eTYkIxy sccl@sccl.cc"
    ];
    users.users.heimdall.openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILREBz4a7g2D+DfvOTHYn+yGiYnhBAU4eMnF6eTYkIxy sccl@sccl.cc"
    ];

    # fail2ban
    services.fail2ban = {
      enable = true;
      ignoreIP = [ "127.0.0.0/8" "::1" "192.168.0.20" ];
      jails = {
        sshd = {
          enabled = true;
          settings = {
            maxretry = 5;
            bantime = "1h";
          };
        };
      };
    };

    # Docker on host (for CI artifacts, not playground)
    virtualisation.docker = {
      enable = true;
      storageDriver = "zfs";
      daemon.settings = {
        log-driver = "json-file";
        log-opts = {
          max-size = "10m";
          max-file = "3";
        };
      };
    };

    # Disable desktop things for headless

    environment.systemPackages = with pkgs; [
      vim
      git
      curl
      wget
      htop
      tmux
      jq
    ];
  };
}
