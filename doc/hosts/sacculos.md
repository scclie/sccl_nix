# sacculos - desktop workstation

main desktop work-gaming machine.

- hostname: `sacculos`
- lan: `192.168.0.20/24` (`enp5s0`) - briefly used `.11` during a fail2ban
  incident (see `doc/router.md`)
- gpu: amd (see `hosts/sacculos/gpu.nix`)
- users: `paper` (main, home-manager), `paper-dis` (second profile)
- layout: `colemak_dh,rulemak` (vial), Niri compositor

## enabled features (`sccl.*`)

- `ui` - Niri/stylix/greetd, Nord theme
- `audio`, `bluetooth`, `net` - pipewire, bluetooth, networkmanager
- `zapret` - DPI bypass
- `mihomo` - TUN proxy (`fakeHwid = "B8A7E6D5C4B3"`), bypass for games
  (steam, cs2, wine, reaper, ...)
- `secrets` - sops scope `personal`
- `playground` - Docker + dev tools
- `nix-ld` - proprietary binaries
- `automount` - USB auto-mount (udisks2 + polkit)
- `files.webdav` - mounts `https://files-lan.sccl.cc:8081/` (SFTPGo WebDAV) at
  `/home/paper/Files`

## dns / proxy notes

- `mihomo` resolves `*.sccl.cc` through LAN Unbound (`192.168.0.10`) so
  subdomains hit the server directly (no Cloudflare loop).
- Exception: `git.sccl.cc` is forced to resolve **publicly** (`1.1.1.1`).
  This fixed `git push` (hairpin SSL Error 19 / the `*.sccl.cc` LAN policy rule
  wasn't matching the auth flow). Keep the `nameserver-policy` override in
  [`nixos/modules/mihomo.nix`](../../nixos/modules/mihomo.nix).

## deploy

```bash
sudo nixos-rebuild switch --flake .#sacculos
```
