# 2.4 GHz HT40− mesh smoke — 2026-08-12

## Scope and result

Exact DKMS 0.1.6 RTL8812AU peers formed the open mesh on the legal channel-13
HT40− profile (`2472 MHz` primary with the channel-9 secondary) under the
active Danish regulatory domain. Exact provenance and bilateral recovery/HWMP
passed before a serialized lifecycle cycle.

```
# summary join_pass=1/1 plink_pass=1/1 root_first_contact=1/1 peer_first_contact=1/1 root_multicast=1/1 peer_multicast=1/1 paths_both=1/1 elapsed_s=8
# usb-errors-since-start
```

Peering completed in 130 ms; directional cold traffic, multicast reachability,
and reciprocal HWMP all passed. The scoped kernel interval had no mac80211
warning, USB `-71`/`-EPROTO`, USB disconnect/reset, or rtw88 RX/TX transport
diagnostic. The test restored the channel-1 HT20 mesh afterward.

## Limit

This is an HT40− smoke only. Sender-captured quantitative multicast,
SAE/AMPE, transfer, and multi-cycle churn remain necessary before the 2.4 GHz
HT40 compatibility gate can pass.
