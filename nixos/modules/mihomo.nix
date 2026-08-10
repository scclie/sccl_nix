{ config, lib, pkgs, ... }:

let
  cfg = config.sccl.mihomo;

  localOverride = pkgs.writeText "mihomo-local-override.yaml" ''
    mixed-port: ${toString cfg.mixedPort}
    socks-port: ${toString cfg.socksPort}
    external-controller: 127.0.0.1:${toString cfg.apiPort}
    mode: rule
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
    rules:
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
      - GEOIP,RU,DIRECT
      - MATCH,RayTun
  '';

  mergeConfig = pkgs.writeScriptBin "mihomo-merge-config" ''
    #!${pkgs.python3.withPackages (ps: [ ps.pyyaml ])}/bin/python3
    import os
    import re
    import subprocess
    import sys
    import urllib.request
    import yaml

    def get_hwid():
        try:
            r = subprocess.run(
                ["${pkgs.iproute2}/bin/ip", "route", "show", "default"],
                capture_output=True, text=True)
        except OSError:
            return None
        for m in re.finditer(r"dev\s+(\S+)", r.stdout):
            dev = m.group(1)
            try:
                with open(f"/sys/class/net/{dev}/type") as f:
                    if f.read().strip() != "1":
                        continue
                with open(f"/sys/class/net/{dev}/address") as f:
                    mac = f.read().strip()
            except OSError:
                continue
            if mac and mac != "00:00:00:00:00:00":
                return mac.replace(":", "").upper()
        return None

    secret_path = sys.argv[1]
    override_path = sys.argv[2]
    output_path = sys.argv[3]

    with open(secret_path) as f:
        sub_url = f.read().strip()

    sub_config = None
    try:
        headers = {"User-Agent": "clash.meta/1.19.24"}
        hwid = get_hwid()
        if hwid:
            headers["x-hwid"] = hwid
        req = urllib.request.Request(sub_url, headers=headers)
        with urllib.request.urlopen(req, timeout=30) as resp:
            sub_config = yaml.safe_load(resp.read())
        print("Fetched subscription successfully")
    except Exception as e:
        print(f"Subscription fetch failed: {e}", file=sys.stderr)
        if os.path.exists(output_path):
            print("Using cached config", file=sys.stderr)
            sys.exit(0)
        else:
            print("No cached config — initial deploy needs manual fetch", file=sys.stderr)
            sub_config = {"proxies": [], "proxy-groups": [], "rules": []}

    with open(override_path) as f:
        override = yaml.safe_load(f)

    for key in override:
        if key == 'rules':
            sub_rules = sub_config.get('rules', [])
            sub_config['rules'] = override['rules'] + sub_rules
        else:
            sub_config[key] = override[key]

    if 'proxies' not in sub_config:
        print("Error: subscription has no proxies", file=sys.stderr)
        sys.exit(1)

    os.makedirs(os.path.dirname(output_path), exist_ok=True)
    with open(output_path, 'w') as f:
        yaml.dump(sub_config, f, default_flow_style=False, allow_unicode=True, sort_keys=False)

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
        AmbientCapabilities = [ "CAP_NET_ADMIN" "CAP_NET_RAW" "CAP_NET_BIND_SERVICE" ];
        CapabilityBoundingSet = [ "CAP_NET_ADMIN" "CAP_NET_RAW" "CAP_NET_BIND_SERVICE" ];
        Restart = "always";
        RestartSec = 5;
        LimitNOFILE = 1048576;

        StateDirectory = "mihomo";
        WorkingDirectory = cfg.configDir;

        ExecStartPre = [
          ''${pkgs.coreutils}/bin/rm -rf ${dashboardDir}''
          ''${pkgs.coreutils}/bin/cp -r --no-preserve=mode ${pkgs.metacubexd} ${dashboardDir}''
          ''${pkgs.coreutils}/bin/mkdir -p ${cfg.configDir}''
          ''${mergeConfig}/bin/mihomo-merge-config ${config.sops.secrets.${cfg.subscriptionSecretName}.path} ${localOverride} ${cfg.configDir}/config.yaml''
          ''${pkgs.coreutils}/bin/chown -R root:root ${cfg.configDir}''
        ];

        ExecStart = "${pkgs.mihomo}/bin/mihomo -d ${cfg.configDir} -f ${cfg.configDir}/config.yaml";

        ExecStopPost = "${pkgs.mihomo}/bin/mihomo -d ${cfg.configDir} cleanup";
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
      # pkgs.clash-verge-rev  # optional GUI control
    ];
  };
}
