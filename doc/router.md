# # home router

## ## lan basics

| item | value |
|---|---|
| subnet | `192.168.0.0/24` |
| gateway | `192.168.0.1` |
| public ip | static from provider |
| dns | `192.168.0.10` (unbound on laeradr) |

## ## dhcp reservations

| host | ip | reason |
|---|---|---|
| laeradr | `192.168.0.10` | server |
| sacculos | `192.168.0.20` | desktop |

## ## port forwarding (wan -> laeradr)

| port | proto | purpose |
|---|---|---|
| 25 | tcp | smtp (sccl.cc, pierdol.ing) |
| 443 | tcp | https |
| 64738 | tcp+udp | mumble |
| 2456-2457 | udp | valheim |

server firewall: [base.nix](../nixos/modules/server/base.nix),
service ports: [server modules](../nixos/modules/server/).
