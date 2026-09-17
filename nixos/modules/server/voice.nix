{ config, lib, pkgs, ... }:
let
  cfg = config.sccl.voice;
  elementCallConfig = pkgs.writeText "element-call-config.json" (builtins.toJSON {
    default_server_config."m.homeserver" = {
      base_url = "https://${cfg.domain}";
      server_name = cfg.domain;
    };
    # join straight into the call; no pre-join lobby / camera preview
    skipLobby = true;
  });
in {
  options.sccl.voice = {
    enable = lib.mkEnableOption "MatrixRTC voice (LiveKit + lk-jwt-service + Element Call)";
    domain = lib.mkOption {
      type = lib.types.str;
      default = "pierdol.ing";
      description = "Matrix server_name; voice is served on livekit./call. subdomains.";
    };
  };

  config = lib.mkIf cfg.enable {
    sops.secrets."livekit/key" = {
      sopsFile = ../../../secrets/apps.yaml;
    };
    sops.secrets."livekit/secret" = {
      sopsFile = ../../../secrets/apps.yaml;
    };

    sops.templates."livekit-keys.yaml".content =
      "${config.sops.placeholder."livekit/key"}: ${config.sops.placeholder."livekit/secret"}";

    sops.templates."lk-jwt.env".content = ''
      LIVEKIT_JWT_BIND=127.0.0.1:8090
      LIVEKIT_URL=wss://livekit.${cfg.domain}
      LIVEKIT_FULL_ACCESS_HOMESERVERS=${cfg.domain}
      LIVEKIT_KEY=${config.sops.placeholder."livekit/key"}
      LIVEKIT_SECRET=${config.sops.placeholder."livekit/secret"}
    '';

    # the host resolver returns cloudflare IPv6 for pierdol.ing (no route),
    # which makes lk-jwt-service time out talking to the homeserver
    networking.hosts."192.168.0.10" = [ "pierdol.ing" ];

    services.livekit = {
      enable = true;
      keyFile = config.sops.templates."livekit-keys.yaml".path;
      settings = {
        port = 7880;
        rtc = {
          tcp_port = 7881;
          port_range_start = 50100;
          port_range_end = 50200;
          use_external_ip = true;
        };
        room.auto_create = false;
      };
    };

    systemd.services.lk-jwt-service = {
      description = "LiveKit JWT service for MatrixRTC";
      after = [ "livekit.service" "network-online.target" ];
      wants = [ "livekit.service" "network-online.target" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        DynamicUser = true;
        EnvironmentFile = config.sops.templates."lk-jwt.env".path;
        ExecStart = lib.getExe pkgs.lk-jwt-service;
        Restart = "on-failure";
        RestartSec = 5;
      };
    };

    # webrtc media reaches the host directly; router forwards these ports
    networking.firewall = {
      allowedTCPPorts = [ 7881 ];
      allowedUDPPortRanges = [ { from = 50100; to = 50200; } ];
    };

    services.nginx.virtualHosts."livekit.${cfg.domain}" = {
      addSSL = true;
      # websocket upgrade does not work over http/2 in nginx; livekit (and
      # element call) need plain http/1.1 for the wss handshake
      http2 = false;
      sslCertificate = "/var/lib/acme/wildcard.${cfg.domain}/fullchain.pem";
      sslCertificateKey = "/var/lib/acme/wildcard.${cfg.domain}/key.pem";
      locations = {
        "/sfu/get" = {
          proxyPass = "http://127.0.0.1:8090";
          # nixos already includes recommended proxy_set_header (Host,
          # X-Forwarded-*); setting them again duplicates the headers and
          # go upstreams (livekit/jwt) reject that with 400
          extraConfig = ''
            proxy_buffering off;
          '';
        };
        "/healthz" = {
          proxyPass = "http://127.0.0.1:8090";
          # nixos already includes recommended proxy_set_header (Host,
          # X-Forwarded-*); setting them again duplicates the headers and
          # go upstreams (livekit/jwt) reject that with 400
          extraConfig = ''
            proxy_buffering off;
          '';
        };
        "/get_token" = {
          proxyPass = "http://127.0.0.1:8090";
          # nixos already includes recommended proxy_set_header (Host,
          # X-Forwarded-*); setting them again duplicates the headers and
          # go upstreams (livekit/jwt) reject that with 400
          extraConfig = ''
            proxy_buffering off;
          '';
        };
        "/" = {
          proxyPass = "http://127.0.0.1:7880";
          proxyWebsockets = true;
          # nixos already includes recommended proxy_set_header (Host,
          # X-Forwarded-*); setting them again duplicates the headers and
          # go upstreams (livekit/jwt) reject that with 400
          extraConfig = ''
            proxy_buffering off;
          '';
        };
      };
    };

    services.nginx.virtualHosts."call.${cfg.domain}" = {
      addSSL = true;
      root = "${pkgs.element-call}";
      sslCertificate = "/var/lib/acme/wildcard.${cfg.domain}/fullchain.pem";
      sslCertificateKey = "/var/lib/acme/wildcard.${cfg.domain}/key.pem";
      locations."= /config.json" = {
        alias = "${elementCallConfig}";
        extraConfig = "default_type application/json;";
      };
    };
  };
}
