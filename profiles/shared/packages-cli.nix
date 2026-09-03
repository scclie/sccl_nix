{ config, pkgs, ... }:

{
  home.packages = with pkgs; [
    # CLI Tools
    # Note: btop, bat, eza are configured via modules
    fastfetch
    ripgrep
    fd
    fzf
    zoxide
    killall
    age
    sops
    gnupg

    # Development
    nixd
    gh
  ];
}
