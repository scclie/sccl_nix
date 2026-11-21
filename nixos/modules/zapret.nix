{ config, lib, pkgs, ... }:

let
  cfg = config.sccl.zapret;
  mihomoEnabled = config.sccl.mihomo.enable or false;

  defaultHosts = [
    "discord.com"
    "discord.gg"
    "discordapp.com"
    "discordapp.net"
    "media.discordapp.net"
    "discord.media"
    "discordvoice.com"
    "docker.io"
    "registry-1.docker.io"
    "registry-2.docker.io"
    "production.cloudflare.docker.com"
    "gcr.io"
    "k8s.gcr.io"
    "registry.k8s.io"
    "quay.io"
    "ghcr.io"
    "youtube.com"
    "googlevideo.com"
    "ytimg.com"
  ];

  hostListGeneral = pkgs.writeText "zapret-hosts-user.txt" (lib.concatMapStringsSep "\n" (h: h) cfg.hosts + "\n");

  hostListExclude = pkgs.writeText "zapret-hosts-user-exclude.txt" (lib.concatMapStringsSep "\n" (h: h) cfg.excludes + "\n");
in {
  options.sccl.zapret = {
    tcpStrategy = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "--dpi-desync=multisplit"
        "--dpi-desync-split-pos=1"
      ];
      description = "nfqws TCP desync arguments; can be overridden per host.";
    };
    hosts = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = defaultHosts;
      description = "Hosts to bypass DPI for (subdomains are matched too).";
    };
    excludes = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "github.com"
        "githubusercontent.com"
        "api.github.com"
        "octocaptcha.com"
        "githubassets.com"
        "github.blog"
        "github.dev"
        "github.status"
        "ghcr.io"
        "objects.githubusercontent.com"
        "nixos.org"
        "channels.nixos.org"
        "cache.nixos.org"
        "nix-community.cachix.org"
        "hydra.nixos.org"
        "status.nixos.org"
        "search.nixos.org"
        "steampowered.com"
        "steamcommunity.com"
        "steamgames.com"
        "steamcontent.com"
        "steam-chat.com"
        "steamstatic.com"
        "steampowered.com.edgesuite.net"
        "akamaihd.net"
        "crates.io"
        "api.zed.dev"
        "zed.dev"
        "zed-extensions.nyc3.digitaloceanspaces.com"
        "digitaloceanspaces.com"
      ];
      description = "Hosts to never touch (subdomains are matched too).";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ pkgs.zapret pkgs.ipset ];

    systemd.services.zapret = {
      description = "Zapret DPI Bypass Service";
      after = [ "network.target" "nss-lookup.target" ];
      wants = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];

      path = [ pkgs.zapret pkgs.ipset pkgs.iptables pkgs.coreutils pkgs.kmod ]
        ++ lib.optional mihomoEnabled pkgs.iproute2;

      preStart = ''
        ${pkgs.kmod}/bin/modprobe xt_NFQUEUE 2>/dev/null || true
        ${pkgs.kmod}/bin/modprobe xt_connbytes 2>/dev/null || true
        ${pkgs.kmod}/bin/modprobe xt_multiport 2>/dev/null || true
        ${pkgs.kmod}/bin/modprobe xt_set 2>/dev/null || true

        if ! ${pkgs.ipset}/bin/ipset list nozapret >/dev/null 2>&1; then
          ${pkgs.ipset}/bin/ipset create nozapret hash:net
        fi

        mkdir -p /var/lib/zapret/ipset
        cp ${hostListGeneral} /var/lib/zapret/ipset/zapret-hosts-user.txt
        cp ${hostListExclude} /var/lib/zapret/ipset/zapret-hosts-user-exclude.txt

        # keep nfqws-generated packets out of mihomo's fucking tunnel
        # the dpi workaround now needs a workaround for the other dpi workaround
        # i just wanted working internet ;k
        ${lib.optionalString mihomoEnabled ''
          # route nfqws-generated packets directly, before Mihomo TUN rules (9000+).
          ${pkgs.iproute2}/bin/ip -4 rule del pref 8999 fwmark 0x40000000/0x40000000 lookup main 2>/dev/null || true
          ${pkgs.iproute2}/bin/ip -4 rule add pref 8999 fwmark 0x40000000/0x40000000 lookup main
        ''}

        ${pkgs.iptables}/bin/iptables -t mangle -D PREROUTING -j ZAPRET 2>/dev/null || true
        ${pkgs.iptables}/bin/iptables -t mangle -D OUTPUT -j ZAPRET 2>/dev/null || true
        ${pkgs.iptables}/bin/iptables -t mangle -F ZAPRET 2>/dev/null || true
        ${pkgs.iptables}/bin/iptables -t mangle -X ZAPRET 2>/dev/null || true

        ${pkgs.iptables}/bin/iptables -t mangle -N ZAPRET
        ${pkgs.iptables}/bin/iptables -t mangle -A ZAPRET -m mark --mark 0x40000000/0x40000000 -j RETURN
        ${lib.optionalString mihomoEnabled ''
          # let mihomo handle the TUN leg
          ${pkgs.iptables}/bin/iptables -t mangle -A ZAPRET -o Meta -j RETURN
        ''}
        ${pkgs.iptables}/bin/iptables -t mangle -A ZAPRET -m set --match-set nozapret dst -j RETURN
        ${pkgs.iptables}/bin/iptables -t mangle -A ZAPRET -p tcp --dport 80 -j NFQUEUE --queue-num 200 --queue-bypass
        ${pkgs.iptables}/bin/iptables -t mangle -A ZAPRET -p tcp --dport 443 -j NFQUEUE --queue-num 200 --queue-bypass
        ${pkgs.iptables}/bin/iptables -t mangle -A ZAPRET -p udp --dport 443 -j NFQUEUE --queue-num 200 --queue-bypass
        ${pkgs.iptables}/bin/iptables -t mangle -I PREROUTING -j ZAPRET
        ${pkgs.iptables}/bin/iptables -t mangle -I OUTPUT -j ZAPRET
      '';

      script = ''
        exec ${pkgs.zapret}/bin/nfqws \
          --qnum=200 --daemon --pidfile=/run/zapret-nfqws.pid \
          --filter-tcp=80,443 \
          --hostlist=/var/lib/zapret/ipset/zapret-hosts-user.txt \
          --hostlist-exclude=/var/lib/zapret/ipset/zapret-hosts-user-exclude.txt \
          ${lib.escapeShellArgs cfg.tcpStrategy} \
          --new \
          --filter-udp=443 \
          --hostlist=/var/lib/zapret/ipset/zapret-hosts-user.txt \
          --hostlist-exclude=/var/lib/zapret/ipset/zapret-hosts-user-exclude.txt \
          --dpi-desync=fake \
          --dpi-desync-repeats=6 \
          --dpi-desync-fake-quic=${pkgs.zapret}/usr/share/zapret/files/fake/quic_initial_www_google_com.bin
      '';

      postStart = ''
        sleep 1
        ${pkgs.iptables}/bin/iptables -t mangle -C POSTROUTING -p udp --dport 1337 \
          -m connbytes --connbytes-dir=original --connbytes-mode=packets --connbytes 1:9 \
          -m mark ! --mark 0x40000000/0x40000000 -m set ! --match-set nozapret dst \
          -j NFQUEUE --queue-num 200 --queue-bypass 2>/dev/null || \
        ${pkgs.iptables}/bin/iptables -t mangle -A POSTROUTING -p udp --dport 1337 \
          -m connbytes --connbytes-dir=original --connbytes-mode=packets --connbytes 1:9 \
          -m mark ! --mark 0x40000000/0x40000000 -m set ! --match-set nozapret dst \
          -j NFQUEUE --queue-num 200 --queue-bypass
      '';

      postStop = ''
        ${lib.optionalString mihomoEnabled ''
          ${pkgs.iproute2}/bin/ip -4 rule del pref 8999 fwmark 0x40000000/0x40000000 lookup main 2>/dev/null || true
        ''}
        ${pkgs.iptables}/bin/iptables -t mangle -D PREROUTING -j ZAPRET 2>/dev/null || true
        ${pkgs.iptables}/bin/iptables -t mangle -D OUTPUT -j ZAPRET 2>/dev/null || true
        ${pkgs.iptables}/bin/iptables -t mangle -F ZAPRET 2>/dev/null || true
        ${pkgs.iptables}/bin/iptables -t mangle -X ZAPRET 2>/dev/null || true
        ${pkgs.iptables}/bin/iptables -t mangle -D POSTROUTING -p udp --dport 1337 \
          -m connbytes --connbytes-dir=original --connbytes-mode=packets --connbytes 1:9 \
          -m mark ! --mark 0x40000000/0x40000000 -m set ! --match-set nozapret dst \
          -j NFQUEUE --queue-num 200 --queue-bypass 2>/dev/null || true
      '';

      serviceConfig = {
        Type = "forking";
        User = "root";
        RemainAfterExit = false;
        PIDFile = "/run/zapret-nfqws.pid";
        Restart = "on-failure";
        RestartSec = 5;
      };
    };
  };
}
