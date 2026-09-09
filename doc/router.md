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
| laeradr | `192.168.0.10` | server (static services) |
| sacculos | `192.168.0.20` | desktop |

## port forwarding (WAN -> laeradr)

| port | proto | purpose |
|---|---|---|
| 443 | TCP | https origin for cf |
