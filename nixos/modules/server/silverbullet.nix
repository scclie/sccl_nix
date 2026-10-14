{ config, lib, ... }:
let
  cfg = config.sccl.silverbullet;
in {
  options.sccl.silverbullet = {
    enable = lib.mkEnableOption "SilverBullet Markdown vault protected by Kanidm";
  };

  config = lib.mkIf cfg.enable {
    services.silverbullet = {
      enable = true;
      listenAddress = "127.0.0.1";
      listenPort = 3003;
      spaceDir = "/tank/silverbullet/space";
    };

    systemd.tmpfiles.rules = [
      "d /tank/silverbullet/space 0750 silverbullet silverbullet -"
    ];

    sccl.proxy.sites.obsi = {
      upstream = "http://127.0.0.1:3003";
      extraConfig = ''
        client_max_body_size 100m;
        auth_request /oauth2/auth;
        error_page 401 = /oauth2/sign_in;
        auth_request_set $auth_user $upstream_http_x_auth_request_user;
        proxy_set_header X-Forwarded-User $auth_user;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
      '';
      extraServerConfig = ''
        location /oauth2/ {
          proxy_pass http://127.0.0.1:4180;
          proxy_set_header Host $host;
          proxy_set_header X-Real-IP $remote_addr;
          proxy_set_header X-Forwarded-Proto $scheme;
        }
        location = /oauth2/auth {
          internal;
          proxy_pass http://127.0.0.1:4180;
          proxy_pass_request_body off;
          proxy_set_header Content-Length "";
          proxy_set_header X-Original-URI $request_uri;
        }
      '';
    };
  };
}
