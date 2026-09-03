{ config, lib, pkgs, ... }:
let
  cfg = config.sccl.sso;
in {
  options.sccl.sso = {
    enable = lib.mkEnableOption "Authelia SSO (off by default, enable when first app with users appears)";
  };

  config = lib.mkIf cfg.enable {
    # Placeholder: Authelia at .18
    # Session cookie on .sccl.cc, nginx auth_request integration
    # Provides Remote-User header to upstream apps
  };
}
