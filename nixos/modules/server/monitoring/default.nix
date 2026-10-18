{ config, lib, pkgs, ... }:
let
  cfg = config.sccl.monitoring;
  containers = builtins.attrNames config.containers;
in {
  options.sccl.monitoring = {
    enable = lib.mkEnableOption "prom++ + grafana + loki + alertmanager";

    telegram.enable = lib.mkEnableOption "telegram alerts";

    alertmanagerTelegramBotToken = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = "telegram bot token file";
      example = "/run/secrets/telegram/bot-token";
    };

    alertmanagerTelegramChatId = lib.mkOption {
      type = lib.types.int;
      default = 0;
      description = "telegram chat id";
    };

    htpasswdFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = "htpasswd file for monitoring when sso is disabled";
    };
  };

  options.containers = lib.mkOption {
    type = lib.types.attrsOf (lib.types.submodule ({ name, ... }: {
      config = lib.mkIf cfg.enable {
        bindMounts."/var/log/journal" = {
          hostPath = "/tank/mon/journal/${name}";
          isReadOnly = false;
        };
        config.services.journald = {
          storage = "persistent";
          extraConfig = "SystemMaxUse=256M";
        };
      };
    }));
  };

  config = lib.mkIf cfg.enable (let
    telegramEnabled = cfg.telegram.enable;
    alertReceiver = if telegramEnabled then "telegram" else "null";
    alertReceivers = lib.optional telegramEnabled {
      name = "telegram";
      telegram_configs = [{
        bot_token_file = cfg.alertmanagerTelegramBotToken;
        chat_id = cfg.alertmanagerTelegramChatId;
        parse_mode = "HTML";
        message = "{{ range .Alerts }}<b>{{ .Labels.alertname }}</b>\n{{ .Annotations.description }}\n{{ end }}";
      }];
    } ++ lib.optional (!telegramEnabled) { name = "null"; };

    # nginx basic auth shared by the prometheus/loki/alertmanager virtual hosts
    authBasic = ''
      auth_basic "Monitoring";
      auth_basic_user_file ${toString cfg.htpasswdFile};
    '';

    # forward-auth to kanidm via oauth2-proxy (replaces basic auth)
    oauthOn = config.sccl.kanidm.enable;
    oauth2AuthRequest = ''
      auth_request /oauth2/auth;
      error_page 401 = /oauth2/sign_in;
      auth_request_set $auth_user $upstream_http_x_auth_request_user;
      proxy_set_header X-Forwarded-User $auth_user;
    '';
    oauth2Locations = ''
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
  in {
    assertions = [{
      assertion = !telegramEnabled || (cfg.alertmanagerTelegramChatId != 0 && cfg.alertmanagerTelegramBotToken != null);
      message = "telegram alerts need a chat id and token file";
    }];

    sops.secrets."telegram/bot-token" = lib.mkIf telegramEnabled {
      sopsFile = ../../../../secrets/apps.yaml;
    };
    sccl.monitoring.alertmanagerTelegramBotToken = lib.mkIf telegramEnabled
      (lib.mkDefault config.sops.secrets."telegram/bot-token".path);

    sops.secrets."monitoring/htpasswd" = {
      sopsFile = ../../../../secrets/apps.yaml;
      owner = "nginx";
      group = "nginx";
      mode = "0440";
    };
    sccl.monitoring.htpasswdFile = lib.mkDefault config.sops.secrets."monitoring/htpasswd".path;

    services.oauth2-proxy = lib.mkIf oauthOn {
      enable = true;
      provider = "oidc";
      oidcIssuerUrl = "https://id.pierdol.ing/oauth2/openid/oauth2proxy";
      clientID = "oauth2proxy";
      clientSecretFile = config.sops.templates."oauth2proxy-client-secret".path;
      cookie = {
        secretFile = config.sops.secrets."oauth2-proxy/cookie-secret".path;
        domain = ".sccl.cc";
        secure = true;
      };
      email.domains = [ "*" ];
      reverseProxy = true;
      trustedProxyIP = [ "127.0.0.1" ];
      setXauthrequest = true;
      proxyPrefix = "/oauth2";
      upstream = "static://202";
      extraConfig = { whitelist-domain = [ ".sccl.cc" ]; };
    };

    systemd.services.oauth2-proxy = lib.mkIf oauthOn {
      after = [ "nginx.service" "kanidm.service" ];
      wants = [ "nginx.service" "kanidm.service" ];
      startLimitIntervalSec = 0;
      serviceConfig.RestartSec = "10s";
    };

    sccl.proxy.sites = {
      grafana = {
        upstream = "http://127.0.0.1:3001";
        rateLimit = "zone=interactive burst=200 nodelay";
      };
      prometheus = {
        upstream = "http://127.0.0.1:9090";
        extraConfig = if oauthOn then oauth2AuthRequest else lib.optionalString (cfg.htpasswdFile != null) authBasic;
        extraServerConfig = lib.optionalString oauthOn oauth2Locations;
      };
      loki = {
        upstream = "http://127.0.0.1:3100";
        extraConfig = if oauthOn then oauth2AuthRequest else lib.optionalString (cfg.htpasswdFile != null) authBasic;
        extraServerConfig = lib.optionalString oauthOn oauth2Locations;
      };
      alertmanager = {
        upstream = "http://127.0.0.1:9093";
        extraConfig = if oauthOn then oauth2AuthRequest else lib.optionalString (cfg.htpasswdFile != null) authBasic;
        extraServerConfig = lib.optionalString oauthOn oauth2Locations;
      };
    };

    # health check
    services.nginx.virtualHosts = {
      "prometheus.${config.sccl.server.domain}" = {
        locations."= /-/healthy" = {
          proxyPass = "http://127.0.0.1:9090";
        };
      };
      "loki.${config.sccl.server.domain}" = {
        locations."= /ready" = {
          proxyPass = "http://127.0.0.1:3100";
        };
      };
      "alertmanager.${config.sccl.server.domain}" = {
        locations."= /-/healthy" = {
          proxyPass = "http://127.0.0.1:9093";
        };
      };
    };

    system.activationScripts.mon-dirs = lib.mkAfter ''
      mkdir -p /tank/mon/prometheus /tank/mon/grafana /tank/mon/loki
      chown prometheus:prometheus /tank/mon/prometheus
      chown grafana:grafana /tank/mon/grafana
      chown -R loki:loki /tank/mon/loki

      mkdir -p /tank/mon/grafana/dashboards/gif
      chown grafana:grafana /tank/mon/grafana/dashboards/gif

      # create grafana key once
      if [ ! -f /etc/grafana/secret_key ]; then
        mkdir -p /etc/grafana
        head -c 32 /dev/urandom | base64 > /etc/grafana/secret_key
      fi
      chown grafana:grafana /etc/grafana/secret_key
      chmod 600 /etc/grafana/secret_key
    '';

    services.prometheus = {
      enable = true;
      package = pkgs.callPackage ./prompp.nix {};
      listenAddress = "127.0.0.1";
      retentionTime = "365d";
      extraFlags = [ "--storage.tsdb.retention.size=40GB" ];
      globalConfig = {
        scrape_interval = "15s";
        evaluation_interval = "15s";
      };
      scrapeConfigs = [
        {
          job_name = "prometheus";
          static_configs = [{ targets = [ "localhost:9090" ]; }];
        }
        {
          job_name = "node";
          static_configs = [{ targets = [ "localhost:9100" ]; }];
        }
        {
          job_name = "nginx";
          static_configs = [{ targets = [ "localhost:9113" ]; }];
        }
        {
          job_name = "blackbox-http";
          metrics_path = "/probe";
          params = { module = [ "http_2xx" ]; };
          static_configs = [{
            targets = [
              "https://sccl.cc"
              "https://xkb.sccl.cc"
              "https://otp-migrate.sccl.cc"
              "https://git.sccl.cc"
              "https://gif.sccl.cc"
            ];
          }];
          relabel_configs = [
            {
              source_labels = [ "__address__" ];
              target_label = "__param_target";
            }
            {
              source_labels = [ "__param_target" ];
              target_label = "instance";
            }
            {
              target_label = "__address__";
              replacement = "localhost:9115";
            }
          ];
        }
        {
          job_name = "gif-app";
          metrics_path = "/metrics";
          static_configs = [{ targets = [ "localhost:8083" ]; }];
        }
      ];
      alertmanagers = [{
        static_configs = [{ targets = [ "localhost:9093" ]; }];
      }];
      ruleFiles = [ ./alerts.yml ];
    };

    systemd.tmpfiles.rules = [
      "d /tank/mon/prometheus/data 0700 prometheus prometheus -"
    ] ++ map (name: "d /tank/mon/journal/${name} 2750 root systemd-journal -") containers;

    # metrics live on the dataset
    systemd.services.prometheus = {
      unitConfig = {
        RequiresMountsFor = "/tank/mon/prometheus";
        AssertPathIsMountPoint = "/tank/mon/prometheus";
      };
      serviceConfig = {
        BindPaths = [ "/tank/mon/prometheus/data:/var/lib/${config.services.prometheus.stateDir}/data" ];
        RestartSec = "10s";
      };
    };

    services.prometheus.exporters.node = {
      enable = true;
      listenAddress = "127.0.0.1";
      port = 9100;
      enabledCollectors = [ "systemd" "zfs" "hwmon" "pressure" ];
      extraFlags = [
        "--collector.systemd.unit-include=.+[.]service"
        "--collector.systemd.unit-exclude=(run-.*|user@.*|user-runtime-dir@.*|session-.*)[.]service"
        "--collector.filesystem.mount-points-exclude=^/(dev|proc|sys|run)($|/)|^/nix/store$"
        "--collector.netdev.device-exclude=^(veth.*|docker.*|br-.*|lo)$"
      ];
    };

    services.prometheus.exporters.nginx = {
      enable = true;
      listenAddress = "127.0.0.1";
      port = 9113;
    };

    services.prometheus.exporters.blackbox = {
      enable = true;
      listenAddress = "127.0.0.1";
      port = 9115;
      configFile = pkgs.writeText "blackbox.yml" ''
        modules:
          http_2xx:
            prober: http
            timeout: 5s
            http:
              valid_http_versions: ["HTTP/1.1", "HTTP/2.0"]
              valid_status_codes: [200, 301, 302]
              method: GET
              follow_redirects: true
              preferred_ip_protocol: ip4
      '';
    };

    services.grafana = {
      enable = true;
      settings = {
        server.http_addr = "127.0.0.1";
        server.http_port = 3001;
        server.root_url = "https://grafana.sccl.cc/";
        "auth.basic".enabled = false;
        security.admin_user = "admin";
        security.admin_password = "admin";
        security.secret_key = "$__file{/etc/grafana/secret_key}";
        "auth.generic_oauth" = lib.mkIf config.sccl.kanidm.enable {
          enabled = true;
          name = "Kanidm";
          client_id = "grafana";
          scopes = "openid profile email groups";
          auth_url = "https://id.pierdol.ing/ui/oauth2";
          token_url = "https://id.pierdol.ing/oauth2/token";
          api_url = "https://id.pierdol.ing/oauth2/openid/grafana/userinfo";
          login_attribute_path = "preferred_username";
          email_attribute_path = "email";
          name_attribute_path = "name";
          role_attribute_path = "contains(groups[*], 'grafana_admins') && 'Admin' || 'Viewer'";
          allow_sign_up = true;
        };
      };
      provision = {
        enable = true;
        dashboards.settings = {
          apiVersion = 1;
          providers = [{
            name = "gif";
            orgId = 1;
            folder = "GIF";
            type = "file";
            disableDeletion = false;
            allowUiUpdates = false;
            updateIntervalSeconds = 10;
            options.path = "/tank/mon/grafana/dashboards/gif";
          } {
            name = "infrastructure";
            orgId = 1;
            type = "file";
            disableDeletion = false;
            allowUiUpdates = false;
            options.path = pkgs.callPackage ./dashboards {};
          }];
        };
        datasources.settings = {
          apiVersion = 1;
          datasources = [
            {
              name = "Prometheus";
              type = "prometheus";
              url = "http://localhost:9090";
              isDefault = true;
            }
            {
              name = "Loki";
              type = "loki";
              url = "http://localhost:3100";
            }
          ];
        };
      };
    };

    systemd.services.grafana.serviceConfig.EnvironmentFile =
      lib.mkIf config.sccl.kanidm.enable config.sops.templates."grafana-oidc.env".path;

    services.loki = {
      enable = true;
      configuration = {
        auth_enabled = false;
        server = {
          http_listen_port = 3100;
          http_listen_address = "127.0.0.1";
        };
        common = {
          path_prefix = "/tank/mon/loki";
          storage.filesystem = {
            chunks_directory = "/tank/mon/loki/chunks";
            rules_directory = "/tank/mon/loki/rules";
          };
          replication_factor = 1;
          ring = {
            instance_addr = "127.0.0.1";
            kvstore.store = "inmemory";
          };
        };
        schema_config.configs = [{
          from = "2024-01-01";
          store = "tsdb";
          object_store = "filesystem";
          schema = "v13";
          index = {
            prefix = "index_";
            period = "24h";
          };
        }];
      };
    };

    environment.etc."alloy/config.alloy".text = ''
      loki.write "default" {
        endpoint {
          url = "http://localhost:3100/loki/api/v1/push"
        }
      }

      loki.relabel "journal" {
        forward_to = []
        rule {
          source_labels = ["__journal__systemd_unit"]
          regex = "(.+[.](service|socket|timer))"
          target_label = "unit"
        }
        rule {
          source_labels = ["unit"]
          regex = "run-.*[.]service"
          target_label = "unit"
          replacement = "transient.service"
        }
        rule {
          source_labels = ["__journal__transport"]
          regex = "kernel"
          target_label = "unit"
          replacement = "kernel"
        }
        rule {
          source_labels = ["__journal_priority_keyword"]
          target_label = "level"
        }
        rule {
          source_labels = ["__journal_container_name"]
          regex = "(.+)"
          target_label = "container"
        }
        rule {
          source_labels = ["__journal_container_name"]
          regex = ".+"
          target_label = "source"
          replacement = "docker"
        }
      }

      loki.source.journal "system" {
        matches = "_HOSTNAME=${config.networking.hostName}"
        forward_to = [loki.write.default.receiver]
        relabel_rules = loki.relabel.journal.rules
        labels = {host = "${config.networking.hostName}", source = "host"}
        max_age = "12h"
      }
    '' + lib.concatMapStrings (name: ''
      loki.source.journal "container_${lib.replaceStrings [ "-" ] [ "_" ] name}" {
        path = "/tank/mon/journal/${name}"
        forward_to = [loki.write.default.receiver]
        relabel_rules = loki.relabel.journal.rules
        labels = {host = "${config.networking.hostName}", source = "nixos", container = "${name}"}
        max_age = "12h"
      }
    '') containers;

    services.alloy = {
      enable = true;
      configPath = "/etc/alloy";
    };

    services.prometheus.alertmanager = {
      enable = true;
      listenAddress = "127.0.0.1";
      port = 9093;
      checkConfig = !telegramEnabled;
      configuration = {
        global = {
          resolve_timeout = "5m";
        };
        route = {
          group_by = [ "alertname" ];
          group_wait = "30s";
          group_interval = "5m";
          repeat_interval = "12h";
          receiver = alertReceiver;
        };
        receivers = alertReceivers;
      };
    };

    networking.firewall = {
      allowedTCPPorts = [];
    };
  });
}
