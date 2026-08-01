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
    };
  };
}
