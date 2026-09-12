{ config, lib, pkgs, ... }:
let
  cfg = config.sccl.monitoring;
in {
  options.sccl.monitoring = {
    enable = lib.mkEnableOption "Monitoring stack (prometheus + grafana + loki + alertmanager)";

    alertmanagerTelegramBotToken = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = "Path to Telegram bot token file (from sops secret)";
      example = "/run/secrets/telegram/bot-token";
    };

    alertmanagerTelegramChatId = lib.mkOption {
      type = lib.types.int;
      default = 0;
      description = "Telegram chat ID for Alertmanager notifications";
    };

    htpasswdFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = ''
        htpasswd file protecting the monitoring web UIs (prometheus, loki,
        alertmanager) served behind nginx basic auth, e.g.
        /run/secrets/monitoring/htpasswd
      '';
    };
  };

  config = lib.mkIf cfg.enable (let
    # Telegram receiver is only valid when a chat id is configured.
    telegramEnabled = cfg.alertmanagerTelegramChatId != 0;
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
  in {
    # Telegram bot token via sops
    sops.secrets."telegram/bot-token" = {
      sopsFile = ../../../secrets/apps.yaml;
    };
    sccl.monitoring.alertmanagerTelegramBotToken = lib.mkDefault config.sops.secrets."telegram/bot-token".path;

    # htpasswd for the monitoring web UIs (create monitoring.htpasswd in apps.yaml)
    sops.secrets."monitoring/htpasswd" = {
      sopsFile = ../../../secrets/apps.yaml;
      owner = "nginx";
      group = "nginx";
      mode = "0440";
    };
    sccl.monitoring.htpasswdFile = lib.mkDefault config.sops.secrets."monitoring/htpasswd".path;

    # reachable via nginx with basic auth
    sccl.proxy.sites = {
      grafana = {
        upstream = "http://127.0.0.1:3001";
      };
      prometheus = {
        upstream = "http://127.0.0.1:9090";
        extraConfig = (lib.optionalString (cfg.htpasswdFile != null) authBasic);
      };
      loki = {
        upstream = "http://127.0.0.1:3100";
        extraConfig = (lib.optionalString (cfg.htpasswdFile != null) authBasic);
      };
      alertmanager = {
        upstream = "http://127.0.0.1:9093";
        extraConfig = (lib.optionalString (cfg.htpasswdFile != null) authBasic);
      };
    };

    # Exempt the health check paths from basic auth so the public Gatus status
    # page can probe the CF-proxied domains end-to-end without credentials.
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

    # Ensure ZFS datasets exist for persistent state
    system.activationScripts.mon-dirs = lib.mkAfter ''
      mkdir -p /tank/mon/prometheus /tank/mon/grafana /tank/mon/loki
      chown prometheus:prometheus /tank/mon/prometheus
      chown grafana:grafana /tank/mon/grafana
      chown -R loki:loki /tank/mon/loki

      # Generate grafana secret key if missing
      if [ ! -f /etc/grafana/secret_key ]; then
        mkdir -p /etc/grafana
        head -c 32 /dev/urandom | base64 > /etc/grafana/secret_key
      fi
      chown grafana:grafana /etc/grafana/secret_key
      chmod 600 /etc/grafana/secret_key
    '';

    services.prometheus = {
      enable = true;
      listenAddress = "127.0.0.1";
      globalConfig = {
        scrape_interval = "15s";
        evaluation_interval = "15s";
      };
      scrapeConfigs = [
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
      ruleFiles = [
        (pkgs.writeText "prometheus-rules.yml" ''
          groups:
            - name: host
              rules:
                - alert: NodeDown
                  expr: up{job="node"} == 0
                  for: 2m
                  labels:
                    severity: critical
                  annotations:
                    summary: "Node exporter down"
                - alert: HighCpuLoad
                  expr: 100 - (avg by(instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100) > 85
                  for: 5m
                  labels:
                    severity: warning
                  annotations:
                    summary: "High CPU load on {{ $labels.instance }}"
                - alert: HighMemoryUsage
                  expr: (1 - node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes) * 100 > 90
                  for: 5m
                  labels:
                    severity: warning
                  annotations:
                    summary: "High memory usage on {{ $labels.instance }}"
                - alert: DiskSpaceLow
                  expr: (node_filesystem_avail_bytes{mountpoint="/"} / node_filesystem_size_bytes{mountpoint="/"}) * 100 < 15
                  for: 10m
                  labels:
                    severity: warning
                  annotations:
                    summary: "Disk space low on {{ $labels.instance }}"
        '')
      ];
    };

    # Prometheus exporters on host (loopback only; scraped by Prometheus on the same machine)
    services.prometheus.exporters.node = {
      enable = true;
      listenAddress = "127.0.0.1";
      port = 9100;
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
        security.admin_user = "admin";
        security.admin_password = "admin"; # change on first login
        security.secret_key = "$__file{/etc/grafana/secret_key}";
      };
      provision = {
        enable = true;
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

    # Alloy replaces deprecated Promtail for log shipping
    environment.etc."alloy/config.alloy".text = ''
      loki.write "default" {
        endpoint {
          url = "http://localhost:3100/loki/api/v1/push"
        }
      }

      loki.source.journal "system" {
        forward_to = [loki.write.default.receiver]
        max_age = "12h"
      }
    '';

    services.alloy = {
      enable = true;
      configPath = "/etc/alloy";
    };

    services.prometheus.alertmanager = {
      enable = true;
      listenAddress = "127.0.0.1";
      port = 9093;
      checkConfig = false; # disabled: placeholder tokens fail validation
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
