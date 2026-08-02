{ config, lib, pkgs, inputs, ... }:
let cfg = config.sccl.secrets;
in {
  options.sccl.secrets.ageKeyFile = lib.mkOption {
    type = lib.types.path;
    default = "/var/lib/sops-nix/key.txt";
    description = "Path to age private key";
  };

  imports = [ inputs.sops-nix.nixosModules.sops ];

  config = lib.mkIf cfg.enable {
    sops = {
      age.keyFile = toString cfg.ageKeyFile;
      defaultSopsFile = ../../secrets/common.yaml;
      secrets = {
        "ssh/id_ed25519" = {
          path = "/home/paper/.ssh/id_ed25519";
          owner = "paper";
        };
        "ssh/id_ed25519_git" = {
          path = "/home/paper/.ssh/id_ed25519_git";
          owner = "paper";
        };
        "ssh/id_ed25519_scclie" = {
          path = "/home/paper/.ssh/id_ed25519_scclie";
          owner = "paper";
        };
        "gpg/signing_key" = {
          path = "/home/paper/.ssh/gpg_signing_key.asc";
          owner = "paper";
        };
      };
    };

    system.activationScripts.importGpgKey = ''
      runuser -u paper -- ${pkgs.gnupg}/bin/gpg --import /home/paper/.ssh/gpg_signing_key.asc
    '';
  };
}
