# 5 GHz DFS HT20 channel-100 result, DKMS 0.1.6

Date: 2026-08-12

## Profile

- two RTL8812AU adapters under the Danish `DFS-ETSI` regulatory profile;
- channel 100 / 5500 MHz, HT20;
- three serialized mesh join attempts.

## Result

Each peer `iw ... mesh join` request failed with `Invalid argument (-22)`
before peering. The device advertises channel 100 as requiring radar detection,
but its nl80211 supported-command list does not include radar-detection start.
The refusal is therefore treated as correct regulatory behaviour for this
driver/hardware combination, not as an IEEE 802.11s functional failure and not
as DFS qualification.

The interval had no new USB transport event. A later journal query initially
included an older 15:35 CEST `-71`/disconnect incident; that timestamp precedes
this 17:29 CEST DFS test and is explicitly excluded from this result.

The normal channel-1 HT20 mesh was provenance-safely restored afterward with
both links `ESTAB` and reciprocal HWMP paths.
