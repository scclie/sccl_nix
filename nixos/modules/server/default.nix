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
    ./gifs.nix
    ./murmur.nix
    ./sftpgo
    ./webdav.nix
    ./vaultwarden.nix
    ./mail.nix
    ./monitoring.nix
    ./status
    ./backup.nix
    ./minecraft.nix
    ./valheim.nix
    ./matrix.nix
    ./radio.nix
    ./sites.nix
    ./sso.nix
  ];
}
