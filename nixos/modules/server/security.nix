{ config, lib, pkgs, ... }:
let
  blockedCAs = [
    "Comodo AAA Services root"
    "emSign ECC Root CA - G3"
    "emSign Root CA - C1"
    "emSign ECC Root CA - C3"
  ];
  apps = {
    gifs = { subnet = "172.30.10.0/24"; ip = "172.30.10.2"; };
    comments = { subnet = "172.30.11.0/24"; ip = "172.30.11.2"; };
    macc = { subnet = "172.30.12.0/24"; ip = "172.30.12.2"; };
  };
in {
  options.containers = lib.mkOption {
    type = lib.types.attrsOf (lib.types.submodule {
      config = lib.mkIf config.sccl.server.enable {
        config.security.pki = {
          caCertificateBlacklist = blockedCAs;
          useCompatibleBundle = true;
        };
      };
    });
  };

  options.virtualisation.oci-containers.containers = lib.mkOption {
    type = lib.types.attrsOf (lib.types.submodule ({ name, ... }: {
      config = lib.mkIf (config.sccl.server.enable && builtins.hasAttr name apps) {
        environment = {
          SSL_CERT_FILE = "/etc/ssl/certs/ca-certificates.crt";
          CURL_CA_BUNDLE = "/etc/ssl/certs/ca-certificates.crt";
          REQUESTS_CA_BUNDLE = "/etc/ssl/certs/ca-certificates.crt";
        };
        volumes = [ "${config.security.pki.caBundle}:/etc/ssl/certs/ca-certificates.crt:ro" ];
        extraOptions = [
          "--network=sccl-${name}"
          "--ip=${apps.${name}.ip}"
          "--cap-drop=ALL"
          "--security-opt=no-new-privileges:true"
          "--pids-limit=256"
          "--memory=768m"
          "--cpus=2"
          "--read-only"
          "--tmpfs=/tmp:rw,nosuid,nodev,noexec,size=64m"
        ];
      };
    }));
  };

  config = lib.mkIf config.sccl.server.enable {
    security.pki = {
      caCertificateBlacklist = blockedCAs;
      useCompatibleBundle = true;
    };
    services.openssh.settings.KbdInteractiveAuthentication = false;
    assertions = [{
      assertion = lib.versionAtLeast config.boot.kernelPackages.kernel.version "6.18.57";
      message = "requires cve-2026-99999 fix kernel";
    }];

    systemd.services = lib.mapAttrs' (name: app:
      lib.nameValuePair "sccl-network-${name}" {
        requires = [ "docker.service" ];
        after = [ "docker.service" ];
        before = [ "docker-${name}.service" ];
        requiredBy = [ "docker-${name}.service" ];
        serviceConfig = { Type = "oneshot"; RemainAfterExit = true; };
        script = ''
          ${pkgs.docker}/bin/docker network inspect sccl-${name} >/dev/null 2>&1 || \
            ${pkgs.docker}/bin/docker network create \
              --subnet ${app.subnet} --opt com.docker.network.bridge.name=br-${name} sccl-${name}
          ${pkgs.iptables}/bin/iptables -C DOCKER-USER -i br-${name} -d 10.69.0.17/32 -p tcp --dport 5000 -j REJECT 2>/dev/null || \
            ${pkgs.iptables}/bin/iptables -I DOCKER-USER 1 -i br-${name} -d 10.69.0.17/32 -p tcp --dport 5000 -j REJECT
        '';
      }
    ) apps;

    networking.firewall.interfaces = {
      br-gifs.allowedTCPPorts = [ 5432 ];
      br-comments.allowedTCPPorts = [ 5432 ];
    };
    services.postgresql.authentication = lib.mkAfter ''
      host gif gif 172.30.10.2/32 scram-sha-256
      host comments comments 172.30.11.2/32 scram-sha-256
    '';

    services.nginx = {
      recommendedProxySettings = true;
      commonHttpConfig = ''
        # nginx >= 1.29.3: retain HSTS even in locations adding Cache-Control.
        add_header_inherit merge;
        add_header Strict-Transport-Security "max-age=86400" always;
        real_ip_header CF-Connecting-IP;
        real_ip_recursive on;
        ${lib.concatMapStringsSep "\n" (range: "set_real_ip_from ${range};") [
          "173.245.48.0/20" "103.21.244.0/22" "103.22.200.0/22"
          "103.31.4.0/22" "141.101.64.0/18" "108.162.192.0/18"
          "190.93.240.0/20" "188.114.96.0/20" "197.234.240.0/22"
          "198.41.128.0/17" "162.158.0.0/15" "104.16.0.0/13"
          "104.24.0.0/14" "172.64.0.0/13" "131.0.72.0/22"
          "2400:cb00::/32" "2606:4700::/32" "2803:f800::/32"
          "2405:b500::/32" "2405:8100::/32" "2a06:98c0::/29"
          "2c0f:f248::/32"
        ]}
      '';
    };
  };
}
