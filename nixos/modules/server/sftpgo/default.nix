{ config, lib, pkgs, ... }:
let
  cfg = config.sccl.sftpgo;
  themeCss = ./sftpgo-nord-sccl.css;
in {
  options.sccl.sftpgo = {
    enable = lib.mkEnableOption "SFTPGo file sharing";
  };

  config = lib.mkIf cfg.enable {
    # Declare secrets at host level
    sops.secrets."sftpgo/admin-username" = {
      sopsFile = ../../../../secrets/apps.yaml;
    };
    sops.secrets."sftpgo/admin-password" = {
      sopsFile = ../../../../secrets/apps.yaml;
    };
    sops.secrets."sftpgo/paper-password" = {
      sopsFile = ../../../../secrets/apps.yaml;
    };

    # First admin is created by sftpgo itself on first boot when
    # data_provider.create_default_admin is enabled; feed it the credentials
    # via an EnvironmentFile rendered from sops into the container.
    sops.templates."sftpgo-env" = {
      content = ''
        SFTPGO_DEFAULT_ADMIN_USERNAME=${config.sops.placeholder."sftpgo/admin-username"}
        SFTPGO_DEFAULT_ADMIN_PASSWORD=${config.sops.placeholder."sftpgo/admin-password"}
      '';
    };

    containers.files-ct = {
      autoStart = true;
      ephemeral = true;
      privateNetwork = true;
      hostAddress = "10.69.0.1";
      localAddress = "10.69.0.11";
      hostBridge = "br-svc";

      bindMounts = {
        "/var/lib/sftpgo" = {
          hostPath = "/tank/sftpgo";
          isReadOnly = false;
        };
        "/run/secrets" = {
          hostPath = "/run/secrets";
          isReadOnly = true;
        };
        "/run/sftpgo-env" = {
          hostPath = config.sops.templates."sftpgo-env".path;
          isReadOnly = true;
        };
      };

      config = { config, pkgs, lib, ... }: {
        system.stateVersion = "26.05";

        nixpkgs.config.allowUnfreePredicate = pkg:
          builtins.elem (lib.getName pkg) [ "sftpgo" ];

        services.sftpgo = {
          enable = true;
          dataDir = "/var/lib/sftpgo/data";
          settings = {
            httpd.bindings = [
              {
                address = "0.0.0.0";
                port = 8080;
                enable_web_admin = false;
                enable_web_client = true;
                enable_rest_api = true;
              }
              {
                address = "0.0.0.0";
                port = 8082;
                enable_web_admin = true;
                enable_web_client = false;
                enable_rest_api = true;
              }
            ];
            webdavd.bindings = [{
              address = "0.0.0.0";
              port = 8081;
            }];
            sftpd.bindings = [{ port = 0; }];
            data_provider.create_default_admin = true;
          };
        };

        systemd.services.sftpgo.serviceConfig.EnvironmentFile = [ "/run/sftpgo-env" ];

        networking.firewall = {
          allowedTCPPorts = [ 8080 8081 8082 ];
        };

        systemd.services.sftpgo-data = {
          description = "Create SFTPGo data directory";
          before = [ "sftpgo.service" ];
          wantedBy = [ "multi-user.target" ];
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
          };
          script = ''
            mkdir -p /var/lib/sftpgo/data
            chown sftpgo:sftpgo /var/lib/sftpgo/data
          '';
        };

        systemd.services.sftpgo-init = {
          description = "Bootstrap SFTPGo paper user";
          after = [ "sftpgo.service" ];
          requires = [ "sftpgo.service" ];
          wantedBy = [ "multi-user.target" ];
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
          };
          path = [ pkgs.curl pkgs.jq ];
          script = ''
            set -euo pipefail
            ADMIN_USER="$(cat /run/secrets/sftpgo/admin-username)"
            ADMIN_PASS="$(cat /run/secrets/sftpgo/admin-password)"
            PAPER_PASS="$(cat /run/secrets/sftpgo/paper-password)"
            BASE="http://127.0.0.1:8080/api/v2"

            for i in $(seq 1 30); do
              curl -sf http://127.0.0.1:8080/healthz >/dev/null 2>&1 && break
              sleep 1
            done

            TOKEN="$(curl -sf -u "$ADMIN_USER:$ADMIN_PASS" "$BASE/token" \
              | jq -r '.access_token')"
            [ -n "$TOKEN" ]

            if ! curl -sf -H "Authorization: Bearer $TOKEN" "$BASE/users/paper" -o /dev/null; then
              install -d -o sftpgo -g sftpgo /var/lib/sftpgo/data/paper
              curl -sf -X POST "$BASE/users" \
                -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' \
                -d "{\"username\":\"paper\",\"password\":\"$PAPER_PASS\",\"home_dir\":\"/var/lib/sftpgo/data/paper\",\"permissions\":{\"/\":[\"*\"]},\"status\":1}" \
                -o /dev/null
            fi
          '';
        };
      };
    };

    sccl.proxy.sites = {
      files = {
        upstream = "http://10.69.0.11:8080";
        extraConfig = ''
          client_max_body_size 100m;
          sub_filter '</head>' '<link rel="stylesheet" href="/assets/css/sftpgo-nord-sccl.css"></head>';
          sub_filter_once on;
          sub_filter_types text/html;
          proxy_set_header Accept-Encoding "";
        '';
        extraServerConfig = ''
          location = /assets/css/sftpgo-nord-sccl.css {
            alias ${themeCss};
            add_header Cache-Control "public, max-age=31536000, immutable";
          }
          location /assets/fonts/ {
            alias /tank/forgejo/custom/public/assets/fonts/;
            add_header Cache-Control "public, max-age=31536000, immutable";
          }
        '';
      };
    };

    services.nginx.virtualHosts = {
      # webdav lan only
      "files-lan" = {
        default = true;
        listen = [{ addr = "192.168.0.10"; port = 8081; ssl = true; }];
        serverName = "files-lan.${config.sccl.server.domain}";
        onlySSL = true;
        sslCertificate = "/var/lib/lan-certs/files-lan.pem";
        sslCertificateKey = "/var/lib/lan-certs/files-lan.key";
        locations."/" = {
          proxyPass = "http://10.69.0.11:8081";
          extraConfig = ''
            client_max_body_size 0;
            proxy_request_buffering off;
          '';
        };
      };
      # admin sftpgo lan only
      "files-lan-admin" = {
        default = true;
        listen = [{ addr = "192.168.0.10"; port = 8082; ssl = true; }];
        serverName = "files-lan.${config.sccl.server.domain}";
        onlySSL = true;
        sslCertificate = "/var/lib/lan-certs/files-lan.pem";
        sslCertificateKey = "/var/lib/lan-certs/files-lan.key";
        locations."/" = {
          proxyPass = "http://10.69.0.11:8082";
          extraConfig = ''
            sub_filter '</head>' '<link rel="stylesheet" href="/assets/css/sftpgo-nord-sccl.css"></head>';
            sub_filter_once on;
            sub_filter_types text/html;
            proxy_set_header Accept-Encoding "";
          '';
        };
        extraConfig = ''
          location = /assets/css/sftpgo-nord-sccl.css {
            alias ${themeCss};
            add_header Cache-Control "public, max-age=31536000, immutable";
          }
          location /assets/fonts/ {
            alias /tank/forgejo/custom/public/assets/fonts/;
            add_header Cache-Control "public, max-age=31536000, immutable";
          }
        '';
      };
    };

    networking.firewall.allowedTCPPorts = [ 8081 8082 ];
  };
}
