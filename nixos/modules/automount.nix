{ config, lib, pkgs, ... }:
let cfg = config.sccl.automount;
in {
  config = lib.mkIf cfg.enable {
    services.udisks2.enable = true;
    security.polkit.enable = true;
    services.gvfs.enable = true;

    # Allow the primary user to mount/unmount drives via udisks2
    # w/o an admin password prompt
    security.polkit.extraConfig = ''
      polkit.addRule(function(action, subject) {
        if ((action.id == "org.freedesktop.udisks2.filesystem-mount-system" ||
             action.id == "org.freedesktop.udisks2.filesystem-mount" ||
             action.id == "org.freedesktop.udisks2.filesystem-mount-other-seat" ||
             action.id == "org.freedesktop.udisks2.filesystem-unmount-others" ||
             action.id == "org.freedesktop.udisks2.filesystem-unmount" ||
             action.id == "org.freedesktop.udisks2.eject-media" ||
             action.id == "org.freedesktop.udisks2.power-off-drive" ||
             action.id == "org.freedesktop.udisks2.power-off-drive-other-seat") &&
            subject.isInGroup("wheel")) {
          return polkit.Result.YES;
        }
      });
    '';
  };
}
