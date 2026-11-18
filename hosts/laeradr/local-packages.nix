{ pkgs, ... }:

{
  # !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
  # NGINX2Root: pinned until nixos-26.05 ships nginx >= 1.30.7.
  services.nginx.package = pkgs.nginxStable.overrideAttrs (_: {
    version = "1.30.7";
    nginxVersion = "1.30.7";
    src = pkgs.fetchurl {
      url = "https://nginx.org/download/nginx-1.30.7.tar.gz";
      hash = "sha256-JWW1yDcFDpWPcPsPc8SOK8pFQq00n9NW9G+wxyYQvG4=";
    };
  });

  # prevent auto-loading the SCTP module used by the reported kernel LPE.
  boot.extraModprobeConfig = ''
    install sctp /run/current-system/sw/bin/false
  '';

  # !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

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
