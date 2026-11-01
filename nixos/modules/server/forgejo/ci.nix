{ config, lib, pkgs, ... }:
let
  ciUid = 23000;
  publish = "/tank/ci/publish";
  sites = [ "sccl.cc" "xkb.sccl" "otp-migrate" "gif.sccl" "pierdol" ];
  siteDirs = map (site: "/tank/sites/${site}") sites;
  dashboards = "/tank/mon/grafana/dashboards/gif";
  siteMounts = lib.concatMapStringsSep " " (dir: "-v ${dir}:${dir}") siteDirs;
  backends = lib.filterAttrs (_: app: app.enable) {
    gifs = { enable = config.sccl.gifs.enable; repository = "gif"; };
    comments = { enable = config.sccl.comments.enable; repository = "comments"; };
    macc = { enable = config.sccl.macc.enable; repository = "macc"; };
  };
in {
  config = lib.mkIf config.sccl.forgejo.enable {
    users.groups.forgejo-ci = {};
    users.users.forgejo-ci = {
      isNormalUser = true;
      uid = ciUid;
      group = "forgejo-ci";
      home = "/var/lib/forgejo-ci";
      createHome = true;
      linger = true;
      subUidRanges = [{ startUid = 1000000; count = 65536; }];
      subGidRanges = [{ startGid = 1000000; count = 65536; }];
    };
    virtualisation.docker.rootless = {
      enable = true;
      setSocketVariable = false;
      extraPackages = [ pkgs.fuse-overlayfs ];
      daemon.settings = {
        storage-driver = "fuse-overlayfs";
        insecure-registries = [ "10.69.0.17:5000" ];
        log-driver = "json-file";
        log-opts = { max-size = "10m"; max-file = "3"; };
      };
    };
    systemd.user.services.docker.unitConfig.ConditionUser = lib.mkForce "forgejo-ci";
    systemd.slices."user-${toString ciUid}".sliceConfig = {
      MemoryMax = "6G";
      CPUQuota = "400%";
      TasksMax = 4096;
    };

    sops.templates."forgejo-runner-config" = {
      content = ''
        log:
          level: info
          job_level: info
        runner:
          capacity: 2
          timeout: 3h
          fetch_interval: 2s
          labels:
            - ubuntu-latest:docker://docker.io/library/node:22-bookworm
        container:
          docker_host: automount
          force_pull: true
          options: "${siteMounts} -v ${dashboards}:${dashboards} -v ${publish}/requests:/publish/requests -v ${config.security.pki.caBundle}:/etc/sccl-ca-bundle.crt -e SSL_CERT_FILE=/etc/sccl-ca-bundle.crt -e CURL_CA_BUNDLE=/etc/sccl-ca-bundle.crt -e GIT_SSL_CAINFO=/etc/sccl-ca-bundle.crt -e NODE_OPTIONS=--use-openssl-ca"
          valid_volumes: ${builtins.toJSON (siteDirs ++ [ dashboards "${publish}/requests" config.security.pki.caBundle ])}
        server:
          connections:
            forgejo:
              url: http://10.69.0.10:3000
              uuid: ${config.sops.placeholder."forgejo/runner-uuid"}
              token: ${config.sops.placeholder."forgejo/runner-token"}
      '';
      path = "/etc/nixos/secrets/forgejo-runner-config.yaml";
      mode = "0400";
    };

    system.activationScripts.sccl-site-symlink-owners = {
      deps = [ "users" ];
      text = lib.concatMapStringsSep "\n" (site: ''
        if [ -L /tank/sites/${site}/public ]; then
          ${pkgs.coreutils}/bin/chown --no-dereference forgejo-ci:forgejo-ci -- /tank/sites/${site}/public
        fi
      '') sites;
    };

    systemd.tmpfiles.rules = [
      "d /tank/ci 0755 root root -"
      "d ${publish} 0755 root root -"
      "d ${publish}/requests 2770 root forgejo-ci -"
      "d ${dashboards} 0755 forgejo-ci forgejo-ci -"
      "Z ${dashboards} - forgejo-ci forgejo-ci -"
    ] ++ lib.concatMap (site: [
      "d /tank/sites/${site} 0755 forgejo-ci forgejo-ci -"
      "d /tank/sites/${site}/releases 0755 forgejo-ci forgejo-ci -"
      "Z /tank/sites/${site}/releases - forgejo-ci forgejo-ci -"
      "z /tank/sites/${site}/public - forgejo-ci forgejo-ci -"
    ]) sites;

    systemd.services = {
      forgejo-runner = {
        description = "Forgejo Actions runner (dedicated rootless engine)";
        after = [ "network-online.target" "user@${toString ciUid}.service" ];
        wants = [ "network-online.target" "user@${toString ciUid}.service" ];
        wantedBy = [ "multi-user.target" ];
        restartTriggers = [ config.sops.templates."forgejo-runner-config".content ];
        environment = {
          HOME = "/var/lib/forgejo-ci";
          XDG_RUNTIME_DIR = "/run/user/${toString ciUid}";
          DOCKER_HOST = "unix:///run/user/${toString ciUid}/docker.sock";
        };
        serviceConfig = {
          User = "forgejo-ci";
          Group = "forgejo-ci";
          WorkingDirectory = "/var/lib/forgejo-ci";
          LoadCredential = [ "config.yaml:/etc/nixos/secrets/forgejo-runner-config.yaml" ];
          ExecStart = "${pkgs.forgejo-runner}/bin/forgejo-runner -c %d/config.yaml daemon";
          Restart = "always";
          RestartSec = 10;
          NoNewPrivileges = true;
          ProtectSystem = "strict";
          # act stages job files in /tmp
          PrivateTmp = true;
          ReadWritePaths = [ "/var/lib/forgejo-ci" "${publish}/requests" "/run/user/${toString ciUid}" dashboards ] ++ siteDirs;
          InaccessiblePaths = [ "/var/run/docker.sock" "/tank/db" "/tank/vw" ];
        };
      };
    } // lib.mapAttrs' (name: app:
      lib.nameValuePair "sccl-deploy-${name}" {
        description = "Deploy ${name} from a CI-approved image digest";
        wantedBy = [ "multi-user.target" ];
        requires = [ "docker.service" "container@registry-ct.service" ];
        after = [ "docker.service" "container@registry-ct.service" ];
        path = [ pkgs.coreutils pkgs.docker pkgs.systemd ];
        environment = {
          DOCKER_HOST = "unix:///run/docker.sock";
          DOCKER_CONFIG = "/var/empty";
        };
        startLimitIntervalSec = 0;
        serviceConfig = {
          Type = "oneshot";
          StateDirectory = "sccl-deploy-${name}";
          StateDirectoryMode = "0700";
          Restart = "on-failure";
          RestartSec = "30s";
          RestartPreventExitStatus = [ 2 ];
          NoNewPrivileges = true;
          PrivateTmp = true;
          PrivateDevices = true;
          ProtectSystem = "strict";
          ProtectHome = true;
          TimeoutStartSec = "15min";
        };
        script = ''
          set -euo pipefail
          request=${publish}/requests/${name}.digest
          [[ ! -L "$request" ]] || exit 2
          [[ -e "$request" ]] || exit 0
          [[ -f "$request" ]] || exit 2
          digest="$(dd if="$request" iflag=nofollow,nonblock,count_bytes count=73 status=none)" || exit 2
          [[ "$digest" =~ ^sha256:[0-9a-f]{64}$ ]] || exit 2
          last="$(cat "$STATE_DIRECTORY/digest" 2>/dev/null || true)"
          [[ "$digest" != "$last" ]] || exit 0
          image=10.69.0.17:5000/scclie/${app.repository}
          docker pull "$image@$digest"
          docker tag "$image@$digest" "$image:main"
          systemctl restart docker-${name}.service
          printf '%s\n' "$digest" > "$STATE_DIRECTORY/digest"
        '';
      }
    ) backends;
    systemd.paths = lib.mapAttrs' (name: _:
      lib.nameValuePair "sccl-deploy-${name}" {
        wantedBy = [ "multi-user.target" ];
        pathConfig = {
          PathChanged = "${publish}/requests/${name}.digest";
          Unit = "sccl-deploy-${name}.service";
        };
      }
    ) backends;
  };
}
