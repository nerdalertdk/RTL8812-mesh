# 5 GHz HT20 quantitative multicast isolation — 2026-08-12

## Method

The exact DKMS 0.1.6 two-RTL8812AU mesh was moved to legal non-DFS channel 149
(`5745 MHz`, HT20) under the active Danish regulatory profile (13 dBm). The
standard sender-captured probe sent 20 rounds of 20 frames in each direction.
Interfaces were resolved by permanent MAC, so the previously weak 2.4 GHz
sender remained `fc:22:1c:30:08:c1` on USB branch `1-1.1`.

The helper then restored the normal channel-1 2.4 GHz HT20 mesh and rechecked
exact module provenance.

## Result

```
# summary root_sender=400 peer_received=400 peer_sender=400 root_received=400
# result classification=pass minimum_delivery_percent=99 expected_sender=400 kernel_events=0
```

Every sender capture and receiver capture contained all 400 frames. The scoped
kernel interval contained no mac80211 warning, USB `-71`/`-EPROTO`, USB
disconnect/reset, or rtw88 RX/TX transport diagnostic.

## Conclusion

The severe loss seen from `…08:c1` on 2.4 GHz is not a generic RTL8812AU USB
transport or mesh-driver failure: the same adapter, USB branch, driver, mesh
role, and quantitative workload are perfect on 5 GHz. It is now localized to
the 2.4 GHz RF path—either that adapter's 2.4 GHz radio path, its attached
antenna, or the 2.4 GHz local environment. An antenna-only exchange remains
the next discriminating physical test.
