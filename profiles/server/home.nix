{ config, pkgs, inputs, ... }:

{
  imports = [
    ../shared/modules/cli.nix
    ../shared/packages-cli.nix
  ];

  home = {
    username = "heimdall";
    homeDirectory = "/home/heimdall";
    stateVersion = "26.05";
  };

  home.packages = with pkgs; [
    rsync
    restic
    tmux
    htop
    iotop
    nixos-rebuild-ng
  ];

  programs.git = {
    enable = true;
    settings = {
      init.defaultBranch = "main";
    };
  };

  programs.home-manager.enable = true;
}
