{ lib, ... }:

let
  mkServiceContainer = {
    name,
    ip,
    mounts ? {},
    config ? ({ ... }: {}),
    extraConfig ? {},
  }: {
    containers.${name} = {
      autoStart = true;
      ephemeral = true;
      privateNetwork = true;
      hostAddress = "10.69.0.1";
      localAddress = ip;
      hostBridge = "br-svc";

      bindMounts = lib.mapAttrs'
        (containerPath: hostPath: {
          name = containerPath;
          value = {
            hostPath = if builtins.isString hostPath then hostPath else hostPath.hostPath;
            isReadOnly = if builtins.isString hostPath then false else (hostPath.readOnly or false);
          };
        })
        mounts;

      inherit config;
    } // extraConfig;
  };
in {
  options.sccl.server.lib.mkServiceContainer = lib.mkOption {
    type = lib.types.unspecified;
    internal = true;
    description = "Helper to create NixOS containers on br-svc with standard isolation";
  };

  config.sccl.server.lib.mkServiceContainer = mkServiceContainer;
}
