# # laeradr monitoring

[`monitoring/default.nix`](../nixos/modules/server/monitoring/default.nix),
[`alerts.yml`](../nixos/modules/server/monitoring/alerts.yml),
[`host config`](../hosts/laeradr/configuration.nix),
[`status module`](../nixos/modules/server/status/default.nix).

## ## stack & access

| service | local | web / auth |
|---|---|---|
| [prom++](../nixos/modules/server/monitoring/prompp.nix) | `127.0.0.1:9090` | `prometheus.sccl.cc`, kanidm via oauth2-proxy |
| grafana | `127.0.0.1:3001` | `grafana.sccl.cc`, kanidm oauth |
| loki | `127.0.0.1:3100` | `loki.sccl.cc`, kanidm via oauth2-proxy |
| alertmanager | `127.0.0.1:9093` | `alertmanager.sccl.cc`, kanidm via oauth2-proxy |
| alloy | journald → loki | — |
| gatus | `127.0.0.1:8080` (nginx upstream) | `status.sccl.cc`, public |

kanidm group grafana: `grafana_admins` == admin, others == viewer.
public health: prom++ / alertmanager `/-/healthy`, loki `/ready`.

## ## metrics

scrape / rules: 15s.

| job | source | metrics |
|---|---|---|
| node | localhost:9100 | cpu, memory, disks, network, temperatures, zfs arc, pressure, systemd |
| nginx | localhost:9113 | connections and requests |
| gif-app | localhost:8083/metrics | gif.sccl.cc app metrics |
| prometheus | localhost:9090 | prom++ memory, series, ingestion rate and storage size |
| blackbox-http | localhost:9115/probe | sccl.cc, xkb.sccl.cc, otp-migrate.sccl.cc, git.sccl.cc, gif.sccl.cc |

## ## retention & dashboards

| what | where |
|---|---|
| metrics | `/tank/mon/prometheus/data`, 365d or 40gb |
| metrics dataset | 50gb quota, auto snapshots off |
| loki | `/tank/mon/loki`, no retention set |
| container journals | `/tank/mon/journal/<container>`, 256m each |
| gatus db | `/tank/mon/gatus/db` |
| infra dashboards | [jsonnet](../nixos/modules/server/monitoring/dashboards/) |
| gif dashboards | `/tank/mon/grafana/dashboards/gif`, from ci |

## ## logs

journald logs to loki:

| source | logs |
|---|---|
| host | host systemd services and kernel |
| docker | oci containers: gifs, macc, comments |
| nixos | files-ct, git-ct, mail, matrix-ct, registry-ct, vaultwarden-ct |
