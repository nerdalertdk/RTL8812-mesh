# 5 GHz HT40+ mesh smoke — 2026-08-12

## Scope and result

Exact DKMS 0.1.6 RTL8812AU peers formed the open mesh on non-DFS channel 149
with `HT40+` (using the legal channel-149/153 block under the active Danish
regulatory domain and its 13 dBm limit). Provenance passed before the join;
bilateral mesh/HWMP recovery took 12 seconds.

One serialized lifecycle cycle then passed with 130 ms peering, bidirectional
cold contact, multicast reachability, and reciprocal HWMP paths:

```
# summary join_pass=1/1 plink_pass=1/1 root_first_contact=1/1 peer_first_contact=1/1 root_multicast=1/1 peer_multicast=1/1 paths_both=1/1 elapsed_s=8
# usb-errors-since-start
```

The scoped kernel interval was empty for mac80211 warnings, USB `-71`/
`-EPROTO`, disconnect/reset, and rtw88 RX/TX transport diagnostics. The test
then restored both radios to the established channel-1 2.4 GHz HT20 mesh.

## Limit

This smoke demonstrates that the driver can establish and cycle an HT40+ mesh
on this legal non-DFS 5 GHz block. It does not close the full 5 GHz HT40
qualification: sender-captured group traffic, SAE/AMPE, transfer, multi-cycle
churn, and DFS behavior remain required.
