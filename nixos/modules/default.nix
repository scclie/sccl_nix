{ ... }:

{
  imports = [
    ./boot.nix
    ./nix.nix
    ./net.nix
    ./timezone.nix
    ./env.nix
    ./audio.nix
    ./bluetooth.nix
    ./kernel.nix
    ./keyboard.nix
    ./amd-gpu.nix
    ./xdg-portal.nix
    ./display-manager.nix
    ./flclashx.nix
    ./playground.nix
  ];
}
