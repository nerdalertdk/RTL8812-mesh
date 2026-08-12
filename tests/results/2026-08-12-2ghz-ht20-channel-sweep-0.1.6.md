# Current-source 2.4 GHz HT20 channel sweep — 2026-08-12

## Method

The exact DKMS 0.1.6 RTL8812AU pair ran the serialized channel-transition
harness across the active Danish HT20 profile, channels 1 through 13. Each
transition waited for both mesh station tables to quiesce, used a two-second
settle interval before netdev down/up, then required bilateral `ESTAB`, cold
traffic in both directions, bidirectional multicast reachability, and HWMP
paths. Both radios were restored to channel 1 HT20 at completion.

## Result

```
# summary channels_pass=13/13 elapsed_s=156
# usb-errors-since-start
```

Every channel passed every functional field. Peer establishment was 4.399 to
9.001 seconds including the deliberate teardown/settle interval. The scoped
kernel interval contained no mac80211 warning, USB `-71`/`-EPROTO`, USB reset
or disconnect, or rtw88 RX/TX transport diagnostic.

## Scope

This closes current-source 2.4 GHz HT20 fresh peering, cold traffic, binary
multicast-reachability, and HWMP coverage for channels 1--13. The separate
sender-captured quantitative multicast gate remains represented by the
channel-13 399/400/400 control; bandwidth-specific HT40 and secured/transfer
qualification remain independent gates.
