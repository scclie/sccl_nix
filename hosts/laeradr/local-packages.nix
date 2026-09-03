{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    vim
    git
    curl
    wget
    htop
    iotop
    tmux
    jq
    ripgrep
    fd
    fish
  ];
}
