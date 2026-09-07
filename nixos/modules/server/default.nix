{ ... }:

{
  imports = [
    ./lib.nix
    ./base.nix
    ./wireguard.nix
    ./dns.nix
    ./proxy.nix
    ./databases.nix
    ./forgejo
    ./sftpgo.nix
    ./vaultwarden.nix
    ./mail.nix
    ./monitoring.nix
    ./status
    ./backup.nix
    ./minecraft.nix
    ./matrix.nix
    ./radio.nix
    ./sso.nix
  ];
}
