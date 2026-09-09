{ config, lib, pkgs, ... }:
let
  cfg = config.sccl.dns;
  domain = cfg.zone;
  lanSubnet = let
    parts = lib.splitString "." cfg.hostIp;
    prefix = lib.concatStringsSep "." (lib.take 3 parts);
  in "${prefix}.0/24";
  records = import ./dns-records.nix {
    inherit domain;
    serverIp = cfg.hostIp;
  };

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

  cfSyncOneshot = r:
    let
      name = if r.name == "@" then domain else "${r.name}.${domain}";
      proxied = if (r ? proxied) && r.proxied then "true" else "false";
    in ''
      NAME='${name}'
      TYPE='${r.type}'
      CONTENT="${r.content}"
      DATA=$($JQ -nc --arg t "$TYPE" --arg n "$NAME" --arg c "$CONTENT" \
        '{type:$t,name:$n,content:$c,ttl:1,proxied:${proxied}}')
      EXISTING=$($CURL -s --max-time 20 "$BASE?name=$NAME" -H "Authorization: Bearer $TOKEN")
      ID=$($JQ -r --arg t "$TYPE" '.result[]? | select(.type == $t) | .id' <<<"$EXISTING" | head -n 1)
      if [ -n "$ID" ]; then
        CODE=$($CURL -s --max-time 20 -X PUT "$BASE/$ID" \
          -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
          --data "$DATA" -o /dev/null -w '%{http_code}')
        echo "cf-dns-sync: $TYPE $NAME updated (http=$CODE)"
      else
        CODE=$($CURL -s --max-time 20 -X POST "$BASE" \
          -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
          --data "$DATA" -o /dev/null -w '%{http_code}')
        echo "cf-dns-sync: $TYPE $NAME created (http=$CODE)"
      fi
      [ "$CODE" = "200" ] || { echo "cf-dns-sync: $TYPE $NAME failed"; exit 1; }
    '';

    cfSyncScript = pkgs.writeShellScript "cf-dns-sync" ''
      set -euo pipefail
      CURL='${pkgs.curl}/bin/curl'
      JQ='${pkgs.jq}/bin/jq'
      TOKEN_FILE=/etc/nixos/secrets/cloudflare-api-token.env
      if [ ! -f "$TOKEN_FILE" ]; then
        echo "cf-dns-sync: cloudflare token not installed yet; skipping"
        exit 0
      fi
      TOKEN=$(tr -d '\r\n' < "$TOKEN_FILE")
      [ -n "$TOKEN" ] || { echo "cf-dns-sync: empty token; skipping"; exit 0; }

      PUBLIC_IP_FILE="${config.sops.secrets."dns/publicIp".path}"
      if [ ! -f "$PUBLIC_IP_FILE" ]; then
        echo "cf-dns-sync: publicIp secret not installed yet; skipping"
        exit 0
      fi
      PUBLIC_IP=$(tr -d '\r\n' < "$PUBLIC_IP_FILE")
      [ -n "$PUBLIC_IP" ] || { echo "cf-dns-sync: empty publicIp; skipping"; exit 0; }

      ZONE=$($CURL -s --max-time 20 "https://api.cloudflare.com/client/v4/zones?name=${domain}" \
        -H "Authorization: Bearer $TOKEN" | $JQ -r '.result[0].id // empty')
      if [ -z "$ZONE" ]; then
        echo "cf-dns-sync: zone ${domain} not found"
        exit 1
      fi
      BASE="https://api.cloudflare.com/client/v4/zones/$ZONE/dns_records"
      body() {
        ${lib.concatStringsSep "\n" (map cfSyncOneshot records.cfRecords)}
        echo "cf-dns-sync: done at $(date)"
      }
      body
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
    sops.secrets."dns/publicIp" = {
      sopsFile = ../../../secrets/infra.yaml;
    };

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
      # laeradr itself keeps public DNS (1.1.1.1/8.8.8.8): gatus and friends
      # must go through the Cloudflare proxy loop, NOT the local zone.
      resolveLocalQueries = false;
      settings = {
        server = {
          interface = [ "127.0.0.1" "::1" cfg.hostIp ];
          access-control = [ "127.0.0.0/8 allow" "::1/128 allow" "${lanSubnet} allow" ];
          do-ip6 = "yes";
          hide-identity = "yes";
          hide-version = "yes";
          minimal-responses = "yes";
          prefetch = "yes";
          serve-expired = "yes";
          serve-expired-ttl = 86400;
          num-threads = 2;
          rrset-cache-size = "128m";
          msg-cache-size = "64m";
          do-not-query-localhost = "no";
          local-zone = [ "\"${domain}.\" transparent" ];
        };
        stub-zone = [{
          name = "${domain}.";
          stub-addr = "127.0.0.1@5300";
        }];
        forward-zone = [{
          name = ".";
          forward-addr = [ "1.1.1.1" "8.8.8.8" ];
        }];
      };
    };

    # lan on 53 (laeradr is the dns for /24)
    networking.firewall = {
      allowedTCPPorts = [ 53 ];
      allowedUDPPorts = [ 53 ];
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
        mkdir -p /var/lib/pdns
        chown pdns:pdns /var/lib/pdns
        if [ ! -f /var/lib/pdns/pdns.sqlite ]; then
          echo "Creating pdns database..."
          ${sqlite3} /var/lib/pdns/pdns.sqlite < ${pdnsSchema}
        fi
        chown pdns:pdns /var/lib/pdns/pdns.sqlite
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

    systemd.services.cf-dns-sync = {
      description = "Sync declarative DNS records to Cloudflare";
      after = [ "network-online.target" "sops-install-secrets.service" ];
      wants = [ "network-online.target" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "oneshot"; # cu
        ExecStart = "${cfSyncScript}";
      };
    };

    systemd.timers.cf-dns-sync = {
      description = "Periodically sync declarative DNS records to Cloudflare";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnBootSec = "5min";
        OnUnitActiveSec = "1h";
        Persistent = true;
      };
    };

    system.activationScripts.cfDnsSync = ''
      if systemctl is-active --quiet network-online.target; then
        ${cfSyncScript}
      fi
    '';
  };
}
