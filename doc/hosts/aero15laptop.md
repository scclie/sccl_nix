# # aero15laptop - laptop

gigabyte aero 15x

- hostname: `aero15laptop`
- role: portable workstation
- user: `paper` (home-manager)

features, overrides: [`hosts/aero15laptop/configuration.nix`](../../hosts/aero15laptop/configuration.nix).

## ## hardware & os

| item | value |
|---|---|
| model | gigabyte aero 15x |
| cpu | intel core i7-8750h (6c/12t, v8) |
| gpu | intel uhd 630 + nvidia gtx 1070 max-q 8 gb |
| ram | ddr4, 16g |
| storage | 2 m.2 slots, 512nvme installed |
| display | 15.6" ips, 1920×1080, 144 hz (`eDP-1`) |
| battery | 94.24 wh stock |
| fs | ext4 `/`, 16 gib swap |
| boot | systemd-boot (uefi), cachy kernel |
| desktop | niri (wayland), nord |
| network | wifi, networkmanager (nmtui) |

## ## config

- [disk layout](../../hosts/aero15laptop/disko.nix)
- [gpu / nvidia offload](../../hosts/aero15laptop/gpu.nix)
- [desktop & keybinds](../../profiles/shared/modules/niri.nix), [bar](../../profiles/shared/modules/waybar.nix)
- [home-manager](../../profiles/paper/home.nix)

keyd / keyboard toggle: [host config](../../hosts/aero15laptop/configuration.nix).

## ## deploy

```bash
sudo nixos-rebuild switch --flake .#aero15laptop
```

or via fish alias 
[`rebuild` / `rebuild-home`](../../profiles/shared/modules/fish.nix).
