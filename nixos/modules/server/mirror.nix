{ config, lib, pkgs, ... }:
let
  cfg = config.sccl.mirror;
  # checksums from https://ziglang.org/download/index.json, reviewed 2026-10-21 (fkn emudhra ca leak :sob:)
  hashes = {
    "0.13.0" = "d45312e61ebcc48032b77bc4cf7fd6915c11fa16e4aad116b66c9468211230ea";
    "0.14.0" = "473ec26806133cf4d1918caf1a410f8403a13d979726a9045b421b685031a982";
    "0.14.1" = "24aeeec8af16c381934a6cd7d95c807a8cb2cf7df9fa40d359aa884195c4716c";
    "0.15.1" = "c61c5da6edeea14ca51ecd5e4520c6f4189ef5250383db33d01848293bfafe05";
    "0.15.2" = "02aa270f183da276e5b5920b1dac44a63f1a49e55050ebde3aecc9eb82f93239";
    "0.16.0" = "70e49664a74374b48b51e6f3fdfbf437f6395d42509050588bd49abe52ba3d00";
  };
  archive = version: pkgs.fetchurl {
    url = "https://ziglang.org/download/${version}/zig-${if lib.versionOlder version "0.14.1" then "linux-x86_64" else "x86_64-linux"}-${version}.tar.xz";
    sha256 = hashes.${version};
  };
  syncScript = pkgs.writeShellScript "mirror-sync" ''
    set -euo pipefail
    ${lib.concatMapStringsSep "\n" (version: ''
      install -Dm444 ${archive version} /tank/mirrors/zig/${version}/zig-x86_64-linux-${version}.tar.xz
    '') cfg.zig.versions}
  '';
in {
  options.sccl.mirror = {
    enable = lib.mkEnableOption "file mirror hosting from /tank/mirrors";

    zig = {
      versions = lib.mkOption {
        type = lib.types.listOf (lib.types.enum (builtins.attrNames hashes));
        default = builtins.attrNames hashes;
        description = "Zig versions to mirror";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    services.nginx.virtualHosts."mirror.pierdol.ing" = {
      serverName = "mirror.pierdol.ing";
      root = "/tank/mirrors";
      forceSSL = true;
      sslCertificate = "/var/lib/acme/wildcard.pierdol.ing/fullchain.pem";
      sslCertificateKey = "/var/lib/acme/wildcard.pierdol.ing/key.pem";
      locations."/" = {
        extraConfig = ''
          autoindex on;
          autoindex_exact_size off;
          autoindex_localtime on;
          add_header Cache-Control "public, max-age=31536000, immutable";
        '';
      };
    };

    systemd.services.mirror-sync = {
      description = "Sync mirror files from upstream";
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${pkgs.bash}/bin/bash ${syncScript}";
        User = "root";
      };
    };

    systemd.timers.mirror-sync = {
      description = "Run mirror sync weekly";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "weekly";
        Persistent = true;
      };
    };
  };
}
