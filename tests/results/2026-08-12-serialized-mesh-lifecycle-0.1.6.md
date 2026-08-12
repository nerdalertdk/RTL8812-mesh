# Serialized mesh lifecycle gate — 2026-08-12

## Scope

This is a single controlled leave/down/up/join cycle of the exact loaded DKMS
0.1.6 RTL8812AU modules on the Raspberry Pi. It exercises the generic
mac80211 netdev lifecycle without interpreting the earlier one-off
`ieee80211_do_stop` warning as a driver fault.

The test used the two permanent-MAC-selected RTL8812AU peers:

- root `fc:22:1c:30:08:c1` (`wlan2`);
- `meshpeer` namespace `fc:22:1c:30:0d:8b` (`wlan1`).

Both operated in the open `overnight-mesh` on channel 1, HT20. The churn
harness first issued mesh leave on both peers, waited until both mesh station
tables had no peer entry, slept for two seconds, then brought both netdevs
down/up and rejoined.

## Result

```
cycle plink_ms root_first_contact peer_first_contact root_multicast peer_multicast root_paths peer_paths
1 130 PASS PASS PASS PASS 1 1
# summary join_pass=1/1 plink_pass=1/1 root_first_contact=1/1 peer_first_contact=1/1 root_multicast=1/1 peer_multicast=1/1 paths_both=1/1 elapsed_s=9
```

The kernel interval beginning immediately before the cycle contained no
`WARNING`, `BUG`, `ieee80211_do_stop`, USB `-71`/`-EPROTO`, disconnect/reset,
or rtw88 RX/TX transport diagnostic. The root and namespace peer passed
directional cold contact, three-frame multicast reachability, and reciprocal
HWMP-path checks.

## Interpretation

The previous warning has not reproduced with serialized mesh teardown, so it
is not currently evidence of a driver lifecycle defect. This single cycle
does not close the multi-cycle current-source churn gate; that gate remains
required before release qualification.
