{ config, pkgs, lib, inputs, hasSecrets ? false, ... }:

{
  imports = [
    ../shared/packages.nix    # Base packages for all users
    ../shared/modules         # Base configurations for all users
    ./packages.nix            # Additional user-specific packages
    ./modules                 # User-specific configuration overrides
  ] ++ lib.optional hasSecrets inputs.sops-nix.homeManagerModules.sops;

  home = {
    username = "paper";
    homeDirectory = "/home/paper";
    stateVersion = "26.05";
  };

  programs.home-manager.enable = true;

  # Stylix theme
  stylix.targets = {
    fish.enable = true;
    vim.enable = true;
    gtk.enable = true;
    rofi.enable = false;
  };

  gtk.theme.name = lib.mkForce "adw-gtk3-dark";

  xdg.desktopEntries = {
    vesktop = {
      name = "Vesktop (Secured)";
      genericName = "Discord Client";
      exec = "vesktop %U";
      icon = "vesktop";
      categories = [ "Network" "Chat" "InstantMessaging" ];
      terminal = false;
      mimeType = [ "x-scheme-handler/discord" ];
    };
  };

} // (lib.optionalAttrs hasSecrets {
  sops = {
    defaultSopsFile = ../../secrets/common.yaml;
    secrets = {
      "ssh/id_ed25519" = {
        path = "${config.home.homeDirectory}/.ssh/id_ed25519";
      };
      "ssh/id_ed25519_git" = {
        path = "${config.home.homeDirectory}/.ssh/id_ed25519_git";
      };
      "ssh/id_ed25519_scclie" = {
        path = "${config.home.homeDirectory}/.ssh/id_ed25519_scclie";
      };
      "gpg/signing_key" = {
        path = "${config.home.homeDirectory}/.ssh/gpg_signing_key.asc";
      };
    };
  };

  home.activation = {
    importGpgKey = lib.hm.dag.entryAfter ["writeBoundary"] ''
      $DRY_RUN_CMD ${pkgs.gnupg}/bin/gpg --import ${config.sops.secrets."gpg/signing_key".path}
    '';
  };
})
