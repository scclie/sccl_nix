{ config, lib, pkgs, ... }:
let
  cfg = config.sccl.dns;
  domain = cfg.zone;
  records = import ./dns-records.nix { inherit domain; serverIp = cfg.hostIp; };

  pdns = pkgs.pdns;
  pdnsutil = "${pdns}/bin/pdnsutil";
  pdnsSchema = "${pdns}/share/doc/pdns/schema.sqlite3.sql";
  sqlite3 = "${pkgs.sqlite}/bin/sqlite3";

  recordCmd = r:
    let
      name = if r.name == "@" then domain else "${r.name}.${domain}";
      content = if r.type == "TXT" then "\"${r.content}\"" else r.content;
    in
    if r.type == "NS" then "${pdnsutil} rrset replace ${domain} '${name}' NS '${r.content}'"
    else if r.type == "MX" then "${pdnsutil} rrset replace ${domain} '${name}' MX '${r.content}'"
    else if r.type == "SOA" then "${pdnsutil} rrset replace ${domain} '${name}' SOA '${r.content}'"
    else "${pdnsutil} rrset replace ${domain} '${name}' ${r.type} '${content}'";

  applyScript = pkgs.writeShellScript "dns-apply" ''
    set -euo pipefail

    ${pdnsutil} create-zone ${domain} || true

    ${lib.concatStringsSep "\n" (map recordCmd records.records)}

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

    # Initialize pdns sqlite DB before pdns starts (pdns 5.x refuses to start
    # against a missing database)
    systemd.services.pdns-init = {
      description = "Initialize PowerDNS gsqlite3 database";
      before = [ "pdns.service" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      script = ''
        if [ ! -f /var/lib/pdns/pdns.sqlite ]; then
          echo "Creating pdns database..."
          mkdir -p /var/lib/pdns
          ${sqlite3} /var/lib/pdns/pdns.sqlite < ${pdnsSchema}
          chown pdns:pdns /var/lib/pdns/pdns.sqlite
        fi
      '';
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
