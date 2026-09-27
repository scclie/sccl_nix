{ config, lib, pkgs, ... }:
let
  cfg = config.sccl.mail;
  containerIp = "10.69.0.9";
  certDomains = [ cfg.domain ] ++ cfg.extraDomains;
  forwardedPorts = [ 25 465 587 993 ];
  forwardPortsSpec = lib.concatStringsSep "," (map toString forwardedPorts);
in {
  options.sccl.mail = {
    enable = lib.mkEnableOption "Stalwart mail server";
    domain = lib.mkOption {
      type = lib.types.str;
      default = "sccl.cc";
      description = "Primary mail domain";
    };
    extraDomains = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "Additional mail domains";
    };
    hostname = lib.mkOption {
      type = lib.types.str;
      default = "mail.sccl.cc";
      description = "Mail server hostname";
    };
  };

  config = lib.mkIf cfg.enable {
    sops.secrets."mail/admin-password" = {
      sopsFile = ../../../secrets/apps.yaml;
    };

    sops.templates."stalwart-env" = {
      content = ''
        STALWART_ADMIN_PASSWORD=${config.sops.placeholder."mail/admin-password"}
      '';
    };

    systemd.tmpfiles.rules = [
      "d /tank/mail 0750 1001 1001 - -"
    ];

    containers.mail = {
      autoStart = true;
      ephemeral = false;
      privateNetwork = true;
      privateUsers = "no";
      hostAddress = "10.69.0.1";
      localAddress = containerIp;
      hostBridge = "br-svc";

      bindMounts = {
        "/var/lib/stalwart" = {
          hostPath = "/tank/mail";
          isReadOnly = false;
        };
        "/run/stalwart-env" = {
          hostPath = config.sops.templates."stalwart-env".path;
          isReadOnly = true;
        };
      } // lib.listToAttrs (map (d: {
        name = "/var/lib/acme/wildcard.${d}";
        value = {
          hostPath = "/var/lib/acme/wildcard.${d}";
          isReadOnly = true;
        };
      }) certDomains);

      config = { pkgs, ... }: {
        system.stateVersion = "26.05";

        users.users.stalwart-mail = {
          uid = 1001;
          isSystemUser = true;
          group = "stalwart-mail";
          extraGroups = [ "acme" ];
        };
        users.groups.stalwart-mail = { gid = 1001; };
        users.users.acme = {
          uid = 999;
          isSystemUser = true;
          group = "acme";
        };
        users.groups.acme = { gid = 999; };

        services.stalwart = {
          enable = true;
          stateVersion = "26.05";
          user = "stalwart-mail";
          group = "stalwart-mail";
          settings = {
            certificate = lib.listToAttrs (map (d: {
              name = d;
              value = {
                cert = "%{file:/var/lib/acme/wildcard.${d}/fullchain.pem}%";
                private-key = "%{file:/var/lib/acme/wildcard.${d}/key.pem}%";
                default = d == cfg.domain;
              };
            }) certDomains);

            server = {
              hostname = cfg.hostname;
              listener = {
                "smtp" = {
                  bind = [ "[::]:25" ];
                  protocol = "smtp";
                };
                "submissions" = {
                  bind = [ "[::]:465" ];
                  protocol = "smtp";
                  tls.implicit = true;
                };
                "submission" = {
                  bind = [ "[::]:587" ];
                  protocol = "smtp";
                };
                "imaps" = {
                  bind = [ "[::]:993" ];
                  protocol = "imap";
                  tls.implicit = true;
                };
                "http" = {
                  bind = [ "[::]:8080" ];
                  protocol = "http";
                };
              };
            };

            lookup.default = {
              hostname = cfg.hostname;
              domain = cfg.domain;
            };

            authentication."fallback-admin" = {
              user = "admin";
              secret = "%{env:STALWART_ADMIN_PASSWORD}%";
            };
            session.rcpt.catch-all = true;
          };
        };

        systemd.services.stalwart.serviceConfig.EnvironmentFile = [ "/run/stalwart-env" ];

        networking.firewall.allowedTCPPorts = forwardedPorts ++ [ 8080 ];
      };
    };

    networking.firewall = {
      allowedTCPPorts = forwardedPorts;
      extraCommands = (lib.concatStringsSep "\n" (map (p: ''
        iptables -t nat -C PREROUTING -p tcp --dport ${toString p} -j DNAT --to-destination ${containerIp}:${toString p} 2>/dev/null || iptables -t nat -A PREROUTING -p tcp --dport ${toString p} -j DNAT --to-destination ${containerIp}:${toString p}
      '') forwardedPorts)) + "\n" + ''
        iptables -C FORWARD -d ${containerIp} -p tcp -m multiport --dports ${forwardPortsSpec} -j ACCEPT 2>/dev/null || iptables -I FORWARD -d ${containerIp} -p tcp -m multiport --dports ${forwardPortsSpec} -j ACCEPT
      '';
    };

    sccl.proxy.sites.webmail = {
      upstream = "http://${containerIp}:8080";
    };
  };
}
