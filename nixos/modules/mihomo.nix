{ config, lib, pkgs, ... }:

let
  cfg = config.sccl.mihomo;

  processRules = lib.concatMapStringsSep "\n" (p: "      - PROCESS-NAME,${p},DIRECT") cfg.bypassProcesses;

  localOverride = pkgs.writeText "mihomo-local-override.yaml" ''
    mixed-port: ${toString cfg.mixedPort}
    socks-port: ${toString cfg.socksPort}
    external-controller: 127.0.0.1:${toString cfg.apiPort}
    mode: rule
    find-process-mode: strict
    dns:
      enable: true
      listen: 127.0.0.1:53
      enhanced-mode: redir-host
      default-nameserver:
        - 1.1.1.1
        - 8.8.8.8
      nameserver:
        - 1.1.1.1
        - 8.8.8.8
    tun:
      enable: true
      stack: gvisor
      auto-route: true
      auto-detect-interface: true
    external-ui: ui
    proxy-groups:
      - name: proxy
        type: select
        use:
          - proxy
    rules:
${processRules}
      - DOMAIN-SUFFIX,github.com,DIRECT
      - DOMAIN-SUFFIX,githubusercontent.com,DIRECT
      - DOMAIN-SUFFIX,live.com,DIRECT
      - DOMAIN-SUFFIX,microsoft.com,DIRECT
      - DOMAIN-SUFFIX,login.live.com,DIRECT
      - DOMAIN-SUFFIX,login.microsoftonline.com,DIRECT
      - DOMAIN-SUFFIX,aka.ms,DIRECT
      - DOMAIN-SUFFIX,xboxlive.com,DIRECT
      - DOMAIN-SUFFIX,prismlauncher.org,DIRECT
      - DOMAIN-SUFFIX,upsilon.theaq.one,DIRECT
      - DOMAIN-SUFFIX,aliexpress.ru,DIRECT
      - GEOIP,RU,DIRECT
      - MATCH,proxy
  '';

  mergeConfig = pkgs.writeScriptBin "mihomo-merge-config" ''
    #!${pkgs.python3.withPackages (ps: [ ps.pyyaml ])}/bin/python3
    import os
    import sys
    import urllib.request
    import yaml

    secret_path = sys.argv[1]
    override_path = sys.argv[2]
    output_path = sys.argv[3]
    fake_hwid = sys.argv[4]

    with open(secret_path) as f:
        sub_url = f.read().strip()

    # Fetch subscription and extract proxies for initial cache
    proxies = []
    try:
        headers = {
            "User-Agent": "clash.meta/1.19.24",
            "x-hwid": fake_hwid,
        }
        req = urllib.request.Request(sub_url, headers=headers)
        with urllib.request.urlopen(req, timeout=30) as resp:
            sub_config = yaml.safe_load(resp.read())
        proxies = sub_config.get('proxies', [])
        print(f"Fetched subscription successfully ({len(proxies)} proxies)")
    except Exception as e:
        print(f"Subscription fetch failed: {e}", file=sys.stderr)

    # Write provider cache so mihomo has proxies even if runtime refresh fails
    provider_dir = os.path.join(os.path.dirname(output_path), 'providers')
    os.makedirs(provider_dir, exist_ok=True)
    cache_path = os.path.join(provider_dir, 'proxy.yaml')
    with open(cache_path, 'w') as f:
        yaml.dump({'proxies': proxies}, f, default_flow_style=False, allow_unicode=True, sort_keys=False)

    base_config = {
        'proxy-providers': {
            'proxy': {
                'type': 'http',
                'url': sub_url,
                'interval': 86400,
                'path': './providers/proxy.yaml',
                'header': {
                    'x-hwid': [fake_hwid],
                    'User-Agent': ['clash.meta/1.19.24'],
                },
            }
        }
    }

    with open(override_path) as f:
        override = yaml.safe_load(f)

    for key in override:
        base_config[key] = override[key]

    os.makedirs(os.path.dirname(output_path), exist_ok=True)
    with open(output_path, 'w') as f:
        yaml.dump(base_config, f, default_flow_style=False, allow_unicode=True, sort_keys=False)

    print(f"Merged config written to {output_path}")
  '';

  dashboardDir = "${cfg.configDir}/ui";
in
{
  options.sccl.mihomo = {
    enable = lib.mkEnableOption "mihomo TUN proxy service";

    subscriptionSecretName = lib.mkOption {
      type = lib.types.str;
      default = "mihomo/subscription-url";
      description = "sops-nix secret name for the subscription URL";
    };

    mixedPort = lib.mkOption {
      type = lib.types.int;
      default = 7890;
    };

    socksPort = lib.mkOption {
      type = lib.types.int;
      default = 7891;
    };

    apiPort = lib.mkOption {
      type = lib.types.int;
      default = 9090;
    };

    bypassProcesses = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = ''
        Process names whose traffic goes DIRECT (bypasses the proxy).
        Matched via PROCESS-NAME rules; useful for games that need
        low-latency direct routing (CS2, Deadlock, etc).
      '';
    };

    fakeHwid = lib.mkOption {
      type = lib.types.str;
      default = lib.substring 0 12 (builtins.hashString "sha256" "mihomo-hwid-${config.networking.hostName}");
      description = "Fake HWID sent with subscription requests (x-hwid header)";
    };

    configDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/mihomo";
    };
  };

  config = lib.mkIf cfg.enable {
    sops.secrets.${cfg.subscriptionSecretName} = {
      owner = "root";
    };

    networking.firewall.extraCommands = ''
      iptables -C FORWARD -i tun0 -j ACCEPT 2>/dev/null || iptables -I FORWARD -i tun0 -j ACCEPT
      iptables -C FORWARD -o tun0 -j ACCEPT 2>/dev/null || iptables -I FORWARD -o tun0 -j ACCEPT
    '';

    systemd.services.mihomo = {
      description = "Mihomo TUN Proxy";
      after = [ "network-online.target" "nss-lookup.target" ];
      wants = [ "network-online.target" ];
      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        Type = "simple";
        User = "root";
        Group = "root";
        AmbientCapabilities = [ "CAP_NET_ADMIN" "CAP_NET_RAW" "CAP_NET_BIND_SERVICE" "CAP_DAC_READ_SEARCH" "CAP_SYS_PTRACE" ];
        CapabilityBoundingSet = [ "CAP_NET_ADMIN" "CAP_NET_RAW" "CAP_NET_BIND_SERVICE" "CAP_DAC_READ_SEARCH" "CAP_SYS_PTRACE" ];
        Restart = "always";
        RestartSec = 5;
        LimitNOFILE = 1048576;
        TimeoutStopSec = 10;
        KillMode = "mixed";
        KillSignal = "SIGKILL";

        StateDirectory = "mihomo";
        WorkingDirectory = cfg.configDir;

        ExecStartPre = [
          ''${pkgs.coreutils}/bin/rm -rf ${dashboardDir}''
          ''${pkgs.coreutils}/bin/cp -r --no-preserve=mode ${pkgs.metacubexd} ${dashboardDir}''
          ''${pkgs.coreutils}/bin/mkdir -p ${cfg.configDir}''
          ''${mergeConfig}/bin/mihomo-merge-config ${config.sops.secrets.${cfg.subscriptionSecretName}.path} ${localOverride} ${cfg.configDir}/config.yaml "${cfg.fakeHwid}"''
          ''${pkgs.coreutils}/bin/chown -R root:root ${cfg.configDir}''
        ];

        ExecStart = "${pkgs.mihomo}/bin/mihomo -d ${cfg.configDir} -f ${cfg.configDir}/config.yaml";
      };
    };

    environment.systemPackages = [
      (pkgs.writeShellScriptBin "vpn-on" ''
        echo "VPN on"
        exec sudo ${pkgs.systemd}/bin/systemctl start mihomo
      '')
      (pkgs.writeShellScriptBin "vpn-off" ''
        echo "VPN off"
        exec sudo ${pkgs.systemd}/bin/systemctl stop mihomo
      '')
    ];
  };
}
