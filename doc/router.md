# home router

## lan basics

| item | value |
|---|---|
| subnet | `192.168.0.0/24` |
| gateway | `192.168.0.1` |
| public ip | static from provider |
| LAN DNS | `192.168.0.10` (Unbound on laeradr) |

## DHCP reservations

| host | ip | reason |
|---|---|---|
| laeradr | `192.168.0.10` | server |
| sacculos | `192.168.0.20` | desktop |

## port forwarding (WAN -> laeradr)

| port | proto | purpose |
|---|---|---|
| 25 | TCP | smtp (MX for sccl.cc, pierdol.ing) |
| 443 | TCP | https origin for cf |
| 64738 | TCP+UDP| murmur (mumble voice server) |
| 2456 | UDP | valheim game |
| 2457 | UDP | valheim query, port+1 |
