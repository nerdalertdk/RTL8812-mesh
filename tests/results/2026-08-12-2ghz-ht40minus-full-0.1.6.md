# 2.4 GHz HT40− full mesh qualification, DKMS 0.1.6

Date: 2026-08-12

## Profile

- two RTL8812AU adapters (`fc:22:1c:30:08:c1` and `fc:22:1c:30:0d:8b`);
- Danish regulatory profile, channel 13 (2472 MHz), HT40−, centre 2462 MHz;
- exact installed DKMS 0.1.6 five-module provenance.

## Open mesh

- five serialized leave/down/up/rejoin cycles all passed, including bilateral
  peering, cold traffic, multicast reachability, and reciprocal HWMP paths;
- 64 MiB SHA-256-verified transfers passed at 2.69 MB/s root-to-peer and
  2.25 MB/s peer-to-root, with reciprocal postflight paths;
- sender-captured multicast delivered 399/400 root-to-peer and 400/400
  peer-to-root (both satisfy the >=99% gate);
- each scoped interval had zero USB transport event.

## Secured mesh

`wpa_sae_mesh_ht40minus.conf` established MFP-protected SAE/AMPE with
peer-specific SAE acceptance and decrypted AMPE at both peers. Bidirectional
20-packet unicast, multicast, and reciprocal HWMP passed. The protected 32 MiB
transfers had matching SHA-256 at 4.04 MB/s root-to-peer and 4.12 MB/s
peer-to-root, with zero transport event.

The secured harness provenance-safely restored the normal open channel-1 HT20
mesh and verified reciprocal paths.
