{ config, lib, pkgs, inputs, ... }:
let cfg = config.sccl.secrets;
in {
  options.sccl.secrets = {
    ageKeyFile = lib.mkOption {
      type = lib.types.path;
      default = "/var/lib/sops-nix/key.txt";
      description = "Path to age private key (fallback if sshKeyPaths not available)";
    };
    user = lib.mkOption {
      type = lib.types.str;
      default = "paper";
      description = "Owner user for deployed secrets (SSH keys, GPG)";
    };
    scopes = lib.mkOption {
      type = lib.types.listOf (lib.types.enum [ "personal" "infra" "db" "apps" ]);
      description = "Sops files available to this host. Required - set explicitly per host.";
    };
  };

  imports = [ inputs.sops-nix.nixosModules.sops ];

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.scopes != [ ];
        message = "sccl.secrets.enable = true requires sccl.secrets.scopes to be set explicitly (e.g. [ \"personal\" ] or [ \"infra\" \"db\" \"apps\" ]). A silent empty default is not allowed.";
      }
    ];

    sops = {
      age = {
        # Auto-detect age key from SSH host key (article recommendation)
        sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
        # Fallback to explicit key file
        keyFile = toString cfg.ageKeyFile;
      };
    } // lib.optionalAttrs (lib.elem "personal" config.sccl.secrets.scopes) {
      # Personal-only secrets (SSH keys, GPG). Server must NOT see these -
      # personal.yaml is encrypted under the personal age key only.
      defaultSopsFile = ../../secrets/personal.yaml;
      secrets = {
        "ssh/id_ed25519" = {
          path = "/home/${cfg.user}/.ssh/id_ed25519";
          owner = cfg.user;
        };
        "ssh/id_ed25519_git" = {
          path = "/home/${cfg.user}/.ssh/id_ed25519_git";
          owner = cfg.user;
        };
        "ssh/id_ed25519_scclie" = {
          path = "/home/${cfg.user}/.ssh/id_ed25519_scclie";
          owner = cfg.user;
        };
        "gpg/signing_key" = {
          path = "/home/${cfg.user}/.ssh/gpg_signing_key.asc";
          owner = cfg.user;
        };
        "forgejo/api-token" = {
          owner = cfg.user;
          mode = "0400";
        };
      };
    };

    system.activationScripts.importGpgKey = lib.mkIf (lib.elem "personal" config.sccl.secrets.scopes) ''
      runuser -u ${cfg.user} -- ${pkgs.gnupg}/bin/gpg --import /home/${cfg.user}/.ssh/gpg_signing_key.asc
    '';
  };
}
