{ pkgs, ... }:

{

  # RESOLVED
  # gonna leave this commented out as a tribute to the wave of vulnerabilities found by ai :D
  #
  # NGINX2Root: pin disabled now that nixpkgs ships fixed nginx.
  #
  # stable, yeah fucking right. so stable it needs yet another security override.
  # gonna pin nginx to this version until the channel catches up.
  # and it's the same fucking shit every time i need to update to a newer
  # version asap — another override that'll just sit there until i eventually have to clean it up.
  # services.nginx.package = pkgs.nginxStable.overrideAttrs (_: {
  #   version = "1.30.7";
  #   nginxVersion = "1.30.7";
  #   src = pkgs.fetchurl {
  #     url = "https://nginx.org/download/nginx-1.30.7.tar.gz";
  #     hash = "sha256-JWW1yDcFDpWPcPsPc8SOK8pFQq00n9NW9G+wxyYQvG4=";
  #   };
  # });

  # prevent auto-loading the SCTP module used by the reported kernel LPE
  # !! keep until the kernel update (6.18.57 rn)
  boot.extraModprobeConfig = ''
    install sctp /run/current-system/sw/bin/false
  '';

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
