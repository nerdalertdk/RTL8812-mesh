# 2.4 GHz channel-13 quantitative multicast isolation — 2026-08-12

## Method

The exact DKMS 0.1.6 mesh used the same permanent-MAC-selected adapters,
roles, USB branches, and 400-frame-per-direction sender-captured workload as
the failing channel-1 probes. It was moved to channel 13 (`2472 MHz`, HT20),
which is separated from the Pi's onboard channel-6 Wi-Fi, then restored to
channel 1 afterward.

## Result

```
# summary root_sender=400 peer_received=399 peer_sender=400 root_received=400
# result classification=pass minimum_delivery_percent=99 expected_sender=400 kernel_events=0
```

The only observed loss was one sender-confirmed root-to-peer group frame
(399/400, 99.75%). The reverse direction was 400/400. The scoped kernel
interval contained no mac80211 warning, USB `-71`/`-EPROTO`, disconnect/reset,
or rtw88 RX/TX transport diagnostic. Both peers were verified restored to
channel-1 HT20 afterward.

## Conclusion

Together with the perfect 5 GHz 400/400 control, this rules out the `…08:c1`
adapter, its antenna, generic USB transport, and the driver as the dominant
source of the channel-1 loss. The loss is specific to the local channel-1 RF
environment. It must be treated as environmental test evidence, not an
RTL8812AU defect; a clean all-channel current-source sweep remains the proper
release gate.
