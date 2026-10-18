# monitoring

metrics are scraped every 15 seconds:

| job | source | metrics |
|---|---|---|
| node | localhost:9100 | cpu, memory, disks, network, temperatures, zfs arc, pressure, systemd |
| nginx | localhost:9113 | connections and requests |
| gif-app | localhost:8083/metrics | gif.sccl.cc app metrics |
| prometheus | localhost:9090 | prom++ memory, series, ingestion rate and storage size |
| blackbox-http | localhost:9115/probe | sccl.cc, xkb.sccl.cc, otp-migrate.sccl.cc, git.sccl.cc, gif.sccl.cc |
