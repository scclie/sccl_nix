# laeradr - home server

heads-up, always-on NixOS server: my apps, git forge, file sharing, pswd manager,
mail, monitoring and more shit.... ewerything runs on a single machine with ZFS and a
handful of NixOS containers.

- hostname: `laeradr`
- role: `sccl.server.enable = true` (+ dns, wireguard, databases, sftpgo, forgejo, vaultwarden, mail, monitoring, status, backup, proxy)
- users: `root`, `heimdall` (primary user, wheel)

## hardware & os

| item | value |
|---|---|
| board | giga AB350M-DS3H V2-CF (AMI Aptio V UEFI) |
| bios | `F52h` |
| cpu | amd ryzen 5 5600x (6c/12t) |
| ram | 16 gib |
| disk | apacer AS350 1 TB (sata3) |
| fs | ZFS pool `tank` (zstd compression, atime off) |
| boot | systemd-boot (UEFI) |
| nic | `enp4s0` (onboard) |

bios-side setup (AC-loss auto power-on, Wake-on-LAN) is documented separately
in [laeradr-bios.md](./laeradr-bios.md).

## net map

| network | address | purpose |
|---|---|---|
| LAN | `192.168.0.10/24` (`enp4s0`) | Static via router DHCP reservation |
| Public origin | * | Behind Cloudflare proxy |
| WireGuard | `10.100.0.1/24` | `wg0`, UDP `51820` |
| Container bridge | `10.69.0.1/24` (`br-svc`) | Service containers (private network, NATed) |

### Container IPs (br-svc, `10.69.0.0/24`)

| IP | Service | Container | Listen ports |
|---|---|---|---|
| `10.69.0.9` | Mail (stalwart-mail) | `mail-ct` | 8080 (admin UI) |
| `10.69.0.10` | Forgejo | `git-ct` | 3000 |
| `10.69.0.11` | SFTPGo | `files-ct` | 8080 web / 8081 webdav / 8082 admin |
| `10.69.0.16` | Vaultwarden | `vaultwarden-ct` | - |
| `10.69.0.17` | Docker Registry (OCI) | `registry-ct` | 5000 |
| `10.69.0.15` | Radio (stub, not deployed) | - | - |
| `10.69.0.18` | Authelia SSO (stub) | - | - |
| `10.69.0.19` | Matrix Synapse (stub, reserved for a separate domain) | - | - |

containers r ephemeral NixOS containers (`containers.*`, `ephemeral = true`,
`privateNetwork = true`) created by the `sccl.server.lib.mkServiceContainer`
helper ([`nixos/modules/server/lib.nix`](../../nixos/modules/server/lib.nix)).
they reach host DBs via the bridge gateway `10.69.0.1`.

### host services

| port | service | bind |
|---|---|---|
| 22 | sshd (key-only) | `192.168.0.10`, `10.100.0.1` |
| 53 | unbound (LAN resolver for `sccl.cc`) | `192.168.0.10` + loopback |
| 5300/lo | PowerDNS authoritative | `127.0.0.1` |
| 80, 443 | nginx + ACME wildcard `*.sccl.cc` | `192.168.0.10` |
| 8081, 8082 | SFTPGo LAN mirrors (TLS) | `192.168.0.10` |
| 3001/lo | grafana | `127.0.0.1` |
| 5432 | pgSQL | `10.69.0.0/24` (bridge) |
| 6379/lo | redis | `127.0.0.1` |
| 8080 | gatus (public monitoring) | upstream via nginx |
| 9090/3100/9093/lo | prometheus / Loki / Alertmanager | `127.0.0.1` |
| 9100/9113/9115/lo | node / nginx / blackbox exporters | `127.0.0.1` |

Firewall (host): TCP `22 80 443 25 465 587 993 8448`, UDP `51820`,
TCP+UDP `25565-25590` (Minecraft, reserved), TCP+UDP `53` for LAN DNS.

## public services (`*.sccl.cc`, HTTPS via nginx + Cloudflare)

| URL | service | upstream |
|---|---|---|
| `https://sccl.cc` | main site | - |
| `https://git.sccl.cc` | Forgejo + Actions | `10.69.0.10:3000` |
| `https://git.sccl.cc/...` | OCI registry (forgejo package/container registry) | `10.69.0.17:5000` |
| `https://files.sccl.cc` | SFTPGo web client | `10.69.0.11:8080` |
| `https://files-lan.sccl.cc:8081/` | SFTPGo WebDAV (LAN mirror, used by sacculos mount) | `192.168.0.10:8081` |
| `https://files-lan.sccl.cc:8082` | SFTPGo admin (LAN only) | `192.168.0.10:8082` |
| `https://pass.sccl.cc` | vaultwarden (+ `/notifications/hub` websocket) | `10.69.0.16` |
| `https://mail.sccl.cc` | mail server admin (stalwart-mail) | `10.69.0.9:8080` |
| `https://status.sccl.cc` | gatus public status page | `127.0.0.1:8080` |
| `https://grafana.sccl.cc` | grafana (dashboards) | `127.0.0.1:3001` |
| `https://prometheus.sccl.cc` | prometheus (basic auth) | `127.0.0.1:9090` |
| `https://loki.sccl.cc` | loki (basic auth) | `127.0.0.1:3100` |
| `https://alertmanager.sccl.cc` | alertmanager (basic auth) | `127.0.0.1:9093` |

grafana is admin-only; prometheus/loki/alertmanager public paths (`/-/healthy`,
`/ready`, `/-/healthy`) are exempt from basic auth so the gatus page can probe
them end-to-end through cf.

mail MX/SPF/DMARC records are authored in PowerDNS. `mail.sccl.cc` A record
points to the LAN IP in the local zone;.

## dns

- **authoritative:** PowerDNS (sqlite, `127.0.0.1:5300`), zone `sccl.cc`
  managed from [`dns-records.nix`](../../nixos/modules/server/dns-records.nix).
  `systemd` `dns-apply` service + hourly timer push the records.
- **resolver:** Unbound on `192.168.0.10:53` answers `*.sccl.cc` locally and
  forwards everything else to `1.1.1.1`/`8.8.8.8`. LAN clients use it for fast
  split-horizon (subdomains → `192.168.0.10` directly, no Cloudflare loop).
- **cf:** `cf-dns-sync` (service + hourly timer + activation script)
  mirrors selected records as proxied.
- **tls:** single wildcard cert `*.sccl.cc` via ACME DNS-01
  (`security.acme`, Cloudflare token from sops `infra.yaml`).

## storage (ZFS `tank`)

| Dataset | Mount | Used by |
|---|---|---|
| `tank/root` | `/` | root fs |
| `tank/nix` | `/nix` (quota 200G) | nix store |
| `tank/data/sites` | `/tank/sites` | static sites |
| `tank/data/apps` | `/tank/apps` | registry, etc. |
| `tank/data/forgejo` | `/tank/forgejo` | forgejo data (incl. custom theme) |
| `tank/data/db` | `/tank/db` | pgSQL |
| `tank/data/mail` | `/tank/mail` | mail storage |
| `tank/data/sftpgo` | `/tank/sftpgo` | SFTPGo data |
| `tank/data/vw` | `/tank/vw` | vaultwarden |
| `tank/data/mon` | `/tank/mon` | prometheus / grafana / loki / gatus |
| `tank/data/minecraft` | `/tank/minecraft` | (reserved) |
| `tank/data/matrix` | `/tank/matrix` | (reserved) |
| `tank/data/music` | `/tank/music` | (reserved) |
| `tank/backups` | `/tank/backups` | local backups |
| `tank/swap` | (zvol 8G) | swap |

all from [`hosts/laeradr/disko.nix`](../../hosts/laeradr/disko.nix).

## Backup

- **sanoid** snapshots: `tank/root`, `tank/data` - hourly 24 / daily 7 /
  weekly 4 / monthly 3 (auto snap + prune).
- **restic** offsite: daily timer, repo `s3:s3.amazonaws.com/backups-sccl`
  (`resticRepository` in host config, credentials in sops `apps.yaml`), backs
  up `/tank/data /tank/forgejo /tank/db /tank/mail /tank/vw /tank/mon`,
  keeps daily 7 / weekly 4 / monthly 3 with prune.

## secrets (sops-nix)

host-scoped secret files under `secrets/`, scopes enabled in host config:
`["infra" "db" "apps"]` (user `heimdall`).

| Scope | File | Typical contents |
|---|---|---|
| infra | `secrets/infra.yaml` | cf API token, wg keys |
| db | `secrets/db.yaml` | pgsql, app passwords |
| apps | `secrets/apps.yaml` | restic, tg bot, monitoring htpasswd, vaultwarden admin token |

secrets decrypt under `/run/secrets/...` at activation. Containers get them
read-only via `/run/secrets` bind mount.

## deploy
usual remote from another machine with the ssh key
```bash
sudo nixos-rebuild switch --flake .#laeradr --target-host root@192.168.0.10
```

users & packages for `heimdall` come from [`profiles/server/`](../../profiles/server/).

## Monitoring & alerts

- prometheus scrapes node/nginx exporters and blackbox HTTP probes; rules
  alert on node-down, high CPU/RAM, low disk.
- am routes to Telegram (bot token + chat id from sops `apps.yaml`).
- loki collects system journal via Alloy.
- gatus shows a public status page (`status.sccl.cc`) for the main services.
