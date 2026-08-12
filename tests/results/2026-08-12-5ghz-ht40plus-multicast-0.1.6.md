# 5 GHz HT40+ quantitative multicast — 2026-08-12

## Scope

The exact DKMS 0.1.6 RTL8812AU pair ran the standard sender-captured group
probe on the legal non-DFS channel-149/153 HT40+ block (`5745 MHz` primary,
40 MHz width) under the active Danish 13 dBm limit. The test then restored the
normal 2.4 GHz HT20 mesh and revalidated module provenance.

## Result

```
# summary root_sender=400 peer_received=400 peer_sender=400 root_received=400
# result classification=pass minimum_delivery_percent=99 expected_sender=400 kernel_events=0
```

Every sender and receiver capture contained all 400 frames in both directions.
The scoped kernel interval had no mac80211 warning, USB `-71`/`-EPROTO`, USB
disconnect/reset, or rtw88 RX/TX transport diagnostic.

## Limit

This closes the quantitative group-traffic portion of the tested non-DFS 5 GHz
HT40+ profile. SAE/AMPE, integrity transfer, multi-cycle churn, endurance, and
DFS-specific behavior still remain before full 5 GHz HT40 qualification.
