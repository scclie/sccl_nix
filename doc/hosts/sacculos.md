# # sacculos - desktop workstation

main desktop work-gaming machine.

- hostname: `sacculos`
- role: main workstation
- user: `paper` (home-manager)

features, overrides: [`hosts/sacculos/configuration.nix`](../../hosts/sacculos/configuration.nix).

## ## hardware & os

| item | value |
|---|---|
| board | asrock ab350m pro4 |
| bios | p7.40 (uefi) |
| cpu | amd ryzen 5 5500x3d (6c/12t) |
| gpu | amd radeon rx 6750 xt |
| ram | 16 gib |
| disks | xpg gammix s11 pro 512 gb (nvme), r5sl240g 240 gb (sata ssd) |
| display | msi mag 272q x50, 27", 2560×1440, 500 hz |
| fs | ext4 `/` and `/home`, 16 gib swap |
| boot | systemd-boot (uefi), cachy kernel |
| os / desktop | nixos 26.05, niri (wayland), nord |
| lan | `192.168.0.20/24`, `enp5s0` |

## ## config

- [disk layout](../../hosts/sacculos/disko.nix)
- [gpu](../../hosts/sacculos/gpu.nix)
- [desktop & keybinds](../../profiles/shared/modules/niri.nix), [bar](../../profiles/shared/modules/waybar.nix)
- [home-manager](../../profiles/paper/home.nix)

## ## deploy

```bash
sudo nixos-rebuild switch --flake .#sacculos
```

or via fish alias 
[`rebuild` / `rebuild-home`](../../profiles/shared/modules/fish.nix).
