{ config, lib, pkgs, ... }:
let
  cfg = config.sccl.dns;
  domain = cfg.zone;
  records = import ./dns-records.nix { inherit domain; serverIp = cfg.hostIp; };

  pdnsutil = "${pkgs.pdns}/bin/pdnsutil";

  recordCmd = r:
    if r.type == "SOA" then ""
    else if r.type == "NS" then "${pdnsutil} replace-rrset ${domain} '${r.name}' NS '${r.content}'"
    else if r.type == "MX" then "${pdnsutil} replace-rrset ${domain} '${r.name}' MX '${r.content}'"
    else "${pdnsutil} replace-rrset ${domain} '${r.name}' ${r.type} '${r.content}'";

  applyScript = pkgs.writeShellScript "dns-apply" ''
    set -euo pipefail

    if [ ! -f /var/lib/pdns/pdns.sqlite ]; then
      echo "Creating pdns database..."
      mkdir -p /var/lib/pdns
      ${pdnsutil} create-zone ${domain}
    fi

    ${pdnsutil} set-soa ${domain} ns1.${domain} hostmaster.${domain} 2026090301 3600 900 604800 300 || true

    ${lib.concatStringsSep "\n" (map recordCmd records.records)}

    ${pdnsutil} set-meta ${domain} PRESIGNED 1 || true

    echo "DNS records applied for ${domain} at $(date)"
  '';
in {
  options.sccl.dns = {
    enable = lib.mkEnableOption "PowerDNS authoritative DNS + Unbound resolver";
    zone = lib.mkOption {
      type = lib.types.str;
      default = "sccl.cc";
      description = "Primary DNS zone";
    };
    hostIp = lib.mkOption {
      type = lib.types.str;
      default = config.sccl.server.hostIp;
      description = "IP that A records point to";
    };
  };

  config = lib.mkIf cfg.enable {
    services.powerdns = {
      enable = true;
      extraConfig = ''
        launch=gsqlite3
        gsqlite3-database=/var/lib/pdns/pdns.sqlite
        gsqlite3-pragma-foreign-keys=true
        gsqlite3-dnssec=yes
        local-address=127.0.0.1:5300
        local-ipv6=
        master=yes
        allow-axfr-ips=127.0.0.0/8
        default-soa-name=ns1.${domain}
        default-soa-mail=hostmaster.${domain}
        default-ttl=3600
        loglevel=4
        security-poll-suffix=
      '';
    };

    services.unbound = {
      enable = true;
      resolveLocalQueries = true;
      settings = {
        server = {
          interface = "127.0.0.1";
          access-control = "127.0.0.0/8 allow";
          do-ip6 = "no";
          hide-identity = "yes";
          hide-version = "yes";
          minimal-responses = "yes";
          prefetch = "yes";
          serve-expired = "yes";
          serve-expired-ttl = 86400;
          num-threads = 2;
          rrset-cache-size = "128m";
          msg-cache-size = "64m";
        };
        forward-zone = [{
          name = ".";
          forward-addr = [ "1.1.1.1" "8.8.8.8" ];
        }];
      };
    };

    systemd.services.dns-apply = {
      description = "Apply DNS records to PowerDNS";
      after = [ "pdns.service" ];
      wants = [ "pdns.service" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = "${applyScript}";
      };
    };

    systemd.timers.dns-apply = {
      description = "Periodically re-apply DNS records";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnBootSec = "5min";
        OnUnitActiveSec = "1h";
        Persistent = true;
      };
    };
  };
}
