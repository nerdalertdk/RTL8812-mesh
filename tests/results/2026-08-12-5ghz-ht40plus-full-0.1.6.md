# Non-DFS 5 GHz HT40+ full mesh qualification, DKMS 0.1.6

Date: 2026-08-12

## Profile

- two RTL8812AU adapters (`fc:22:1c:30:08:c1` and `fc:22:1c:30:0d:8b`);
- Danish non-DFS primary channel 149 / 5745 MHz, HT40+ through channel 153,
  centre 5755 MHz, enforced 13 dBm;
- exact installed DKMS 0.1.6 five-module provenance.

## Result

- five serialized leave/down/up/rejoin cycles passed, including bilateral
  peering, cold traffic, multicast reachability, and reciprocal HWMP paths;
- `iw dev info` verified both protected peers at width 40 MHz;
- 64 MiB SHA-256-verified open transfers passed at 13.84 MB/s root-to-peer and
  9.53 MB/s peer-to-root;
- sender-captured multicast delivered 400/400 in both directions;
- SAE/AMPE proved peer-specific acceptance, decrypted AMPE, MFP,
  authorization, bidirectional traffic, multicast, and HWMP;
- protected 32 MiB SHA-256 transfers passed at 8.21 MB/s root-to-peer and
  12.82 MB/s peer-to-root;
- all scoped intervals had zero USB transport event.

The secured harness provenance-safely restored the normal open channel-1 HT20
mesh with reciprocal HWMP paths.
