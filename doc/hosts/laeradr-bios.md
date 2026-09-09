# laeradr - bios settings (AC-loss auto power-on & Wake-on-LAN)

why this was done: `laeradr` runs headless (no monitor, gpu (i cant setup gpu in my sff case lmao)), and the board would
not come back up after a power cut. Frst the machine was never booted
automatically after AC restore; by default AMI has `Restore On AC Power Loss =
Disabled`. Since there's no monitor to enter the BIOS menus, the hidden AMI
settings had to be changed from OS using AMISCE/SCELNX.

## ingredients

AMI UEFI AMISCE tool (`sceelnx64`) + helper scripts from
  [/scclie/scelinux](https://git.sccl.cc/scclie/scelinux).
on NixOS the binary cant run out of the box (stub-ld + missing libstdc++).

fix one-time:

  ```bash
  nix-shell -p patchelf gcc-unwrapped --run '
    export LD_LIBRARY_PATH=$(dirname $(find /nix/store -name libstdc++.so.6 -path "*/lib/*" | head -1))
    patchelf --set-interpreter /nix/store/*-glibc-*/lib/ld-linux-x86-64.so.2 sceelnx64
    ./sceelnx64'
  ```

the tool writes NVRAM via SMI from the running OS; a full power cycle
  (not reboot) is required for changes to take effect.


workflow: `./backup.sh before` -> `./export.sh nvram.txt` -> move the `*` on the
desired option in the export -> `./import.sh nvram.txt` -> full power cycle.

| setting | token | offset | value set | effective? |
|---|---|---|---|---|
| Restore On AC Power Loss | `0x1D8` | `0xC8` | `*[01] Power On` | yes, persists |
| AC BACK | `0x239` | `0x213` | `*[01] Always On` | yes, persists - this is the one that matters |
| Ac Loss Control | `0x1E3` | `0x1C2` | `*[01] Always On` | no - the board re-initializes this token to `Always Off` at every POST; safe to ignore |
| Wake on LAN | `0x244` | `0x258` | `*[01] Enabled` | yes (was already the default on my motherboard) |

notes:

- `AC BACK` help text literally describes the behavior: *"Always On = System is
  turned on upon power return"*. It persists in flash NVRAM and is honored.
- `Ac Loss Control` (`PchAcLossControl`) reverts to Always Off at each POST
  no matter what is written. The other two tokens are enough.
- settings live in flash NVRAM, not CMOS - a dead CR2032 does not wipe them
  (verified: values survived full unplugs; RTC kept correct time, battery fine).

## verif

```bash
# after a power cycle, re-export and check the two working tokens:
nix-shell -p patchelf gcc-unwrapped --run './export.sh verify.txt'
./search.sh "Restore On AC Power Loss" verify.txt   # expect *[01]Power On
./search.sh "AC BACK" verify.txt                    # expect *[01]Always On
```

behavior after the change:

- **real outage** (power lost while the server is running): it boots itself
  back up when AC returns - seconds after replug, no button needed.
- **soft shutdown then outage** (`shutdown -h now`, then power cut): stays off;
  the firmware only honors auto-power-on from a running (S0) state.

## wake-on-lan

- NIC: `enp4s0`.
- arming is done at every boot by the `wol-arm` systemd service
  (added in [`nixos/modules/server/base.nix`](../../nixos/modules/server/base.nix)):
  `ethtool -s enp4s0 wol g`. Arming re-set after each AC loss/power cycle.
- check: `ethtool enp4s0 | grep Wake-on` -> should print `Wake-on: g`.
- wake from any machine on the same LAN:

  ```bash
  etherwake -i <lan-iface> <MAC>
  # or
  wakeonlan <MAC>
  ```

- if the AC was fully removed, the server auto-boots anyway (see above);
  WOL is only needed when it's sitting in S5 with power present.
