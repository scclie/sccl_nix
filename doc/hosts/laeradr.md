# # laeradr - home server

server with all my shit.

- hostname: `laeradr`
- role: `sccl.server.enable = true`
- users: `root`, `heimdall` (wheel)

features, overrides: [`hosts/laeradr/configuration.nix`](../../hosts/laeradr/configuration.nix).

## ## hardware & os

| item | value |
|---|---|
| board | gigabyte ab350m-ds3h v2 |
| bios | f52h |
| cpu | amd ryzen 5 5600x 4.7ghz (6c/12t) |
| ram | 16 gib |
| disk | apacer as350 1 tb (sata3) |
| fs | zfs `tank`, zstd, atime off |
| boot | systemd-boot (uefi) |
| nic | `enp4s0` (onboard) |

[bios](laeradr-bios.md).

## ## net map

| network | address | purpose |
|---|---|---|
| lan | `192.168.0.10/24`, `enp4s0` | router dhcp reservation |
| wireguard | `10.100.0.1/24`, `wg0` | udp `51820` |
| containers | `10.69.0.1/24`, `br-svc` | gateway / host db access |
| dns | `192.168.0.10:53` | unbound, local `sccl.cc` / `pierdol.ing` |

### containers

| container | ip | ports |
|---|---|---|
| `mail` | `10.69.0.9` | 25 / 465 / 587 / 993, admin 8080 |
| `git-ct` | `10.69.0.10` | 3000 |
| `files-ct` | `10.69.0.11` | web 8080, webdav 8081, admin 8082 |
| `vaultwarden-ct` | `10.69.0.16` | proxy → 8000 |
| `registry-ct` | `10.69.0.17` | 5000, internal only |
| `matrix-ct` | `10.69.0.19` | 6167 |

## ## access

| what | where |
|---|---|
| ssh | `root@192.168.0.10` / `heimdall@192.168.0.10`, key only |
| git / ci | [git.sccl.cc](https://git.sccl.cc) |
| files | [files.sccl.cc](https://files.sccl.cc) |
| webdav, lan | `https://files-lan.sccl.cc:8081/` |
| files admin, lan | [files-lan.sccl.cc:8082](https://files-lan.sccl.cc:8082) |
| passwords | [pass.sccl.cc](https://pass.sccl.cc) |
| mail admin | [webmail.sccl.cc](https://webmail.sccl.cc) |
| accounts / sso | [id.pierdol.ing](https://id.pierdol.ing) |
| matrix / accounts | [chat.pierdol.ing](https://chat.pierdol.ing) / [macc.pierdol.ing](https://macc.pierdol.ing) |
| notes | [obsi.sccl.cc](https://obsi.sccl.cc) |
| monitoring / status | [grafana.sccl.cc](https://grafana.sccl.cc) / [status.sccl.cc](https://status.sccl.cc) |
| valheim / map | [valheim.pierdol.ing](https://valheim.pierdol.ing) / [map-valheim.pierdol.ing](https://map-valheim.pierdol.ing) |
| mumble | `murmur.sccl.cc:64738` |

[wan ports / router](../router.md) · [metrics / logs / alerts](../monitoring.md).

## ## storage

| what | path |
|---|---|
| postgres | `/tank/db/postgresql` |
| git / registry | `/tank/forgejo`, `/tank/apps/registry` |
| files / mail / passwords | `/tank/sftpgo`, `/tank/mail`, `/tank/vw` |
| metrics / logs | `/tank/mon` |
| sites / notes | `/tank/sites`, `/tank/silverbullet/space` |
| matrix / bridge | `/tank/matrix`, `/tank/discord-bridge` |
| game worlds | `/tank/valheim` |

datasets, quotas: [disko.nix](../../hosts/laeradr/disko.nix).

<a id="backup"></a>

## ## backup

| what | schedule / keep |
|---|---|
| sanoid | hourly 24 / daily 7 / weekly 4 / monthly 3 |
| restic | daily, `restic-backup.timer`; daily 7 / weekly 4 / monthly 3 |
| offsite repo | `s3:s3.amazonaws.com/backups-sccl` |

**gaps:** sanoid is not recursive; restic misses `/tank/sftpgo` and
`/tank/silverbullet`.

paths / policy: [backup.nix](../../nixos/modules/server/backup.nix).

## ## config

- [server modules](../../nixos/modules/server/), [ci / deploy](../../nixos/modules/server/forgejo/ci.nix)
- dns records: [sccl.cc](../../nixos/modules/server/dns-records.nix), [pierdol.ing](../../nixos/modules/server/dns-records-pierdolling.nix)
- [secrets](../../secrets/), [setup](../../docs/secrets-setup.md)
- [heimdall profile](../../profiles/server/)

## ## deploy

usual remote from another machine with the ssh key

```bash
sudo nixos-rebuild switch --flake .#laeradr --target-host root@192.168.0.10
```
