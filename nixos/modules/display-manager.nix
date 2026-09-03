{ config, lib, pkgs, ... }:

lib.mkIf config.sccl.ui.enable {
  services.greetd = {
    enable = true;
    settings = {
      default_session = {
        command = "${pkgs.tuigreet}/bin/tuigreet --time --remember --cmd niri-session"; # tui, minimal af
        user = "greeter";
      };
    };
  };

  environment.systemPackages = [ pkgs.tuigreet ];
}
