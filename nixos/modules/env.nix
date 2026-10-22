{ config, lib, pkgs, ... }:

{
  environment = {
    variables = {
      EDITOR = "vim"; # btw i use vim
      VISUAL = "vim"; # visual, ok.
    };

    sessionVariables = {
      SSL_CERT_FILE = "/etc/ssl/certs/ca-certificates.crt";
      NIX_SSL_CERT_FILE = "/etc/ssl/certs/ca-certificates.crt";
      REQUESTS_CA_BUNDLE = "/etc/ssl/certs/ca-certificates.crt";
      NIXOS_OZONE_WL = "1";  # Wayland electron
    };
  };
}
