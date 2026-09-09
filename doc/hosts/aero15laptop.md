# aero15laptop - laptop

portable machine (Gigabyte Aero 15).

- hostname: `aero15laptop`
- network: wireless (NetworkManager, nmtui)
- gpu: NVIDIA (see `hosts/aero15laptop/gpu.nix`)
- users: `paper` (main, home-manager)
- kb layout: `colemak_dh,rulemak` applied at the hardware level - `keyd`
  remaps the builtin keyboard (DH wide-angle + angle mod, Russian layer,
  `RCtrl → RWIN`, `F12` switches layers); Niri uses the same variant
- openssh enabled (`root` with initial password - change it)

## Enabled features (`sccl.*`)

- `ui`, `audio`, `bluetooth`, `net`
- `mihomo` - TUN proxy (`fakeHwid = "B8A7E6D5C4B3"`, no bypass list)
- `secrets` - sops scope `personal`
- `nix-ld` - proprietary binaries
- `services.keyd` - builtin keyboard remap (see config for the layers)

## deploy

i usually put everything right on the machine

```bash
sudo nixos-rebuild switch --flake .#aero15laptop

# or via fish alias (see 'profiles/shared/modules/fish.nix')
rebuild aero15laptop
```
