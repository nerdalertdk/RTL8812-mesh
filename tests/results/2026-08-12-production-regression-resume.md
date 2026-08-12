# Production DKMS 0.1.5 resumed regression — 2026-08-12

## Test topology

Two RTL8812AU adapters ran an open and secured IEEE 802.11s mesh on channel 1
HT20. `fc:22:1c:30:08:c1` used USB branch `1-1.4`; `fc:22:1c:30:0d:8b` used
the alternate branch `1-1.1`. Both enumerated at 480 Mb/s. Exact production
DKMS 0.1.5 provenance passed before and after the secured test.

## Open churn and HWMP

The first retained 20-cycle run (`churn-20260812T121136Z.log`) had a single
root-to-peer cold-contact miss (19/20), with every peer link, multicast check,
reverse cold contact, and HWMP-path check passing. It had no kernel transport
event and no current throttle bit. The exact repeat
(`churn-20260812T121424Z.log`) passed all required values: 20/20 joins, peer
links, root and peer cold contacts, both multicast directions, and bilateral
HWMP paths in 125 seconds, with zero kernel transport events.

The first miss is retained as regression history; it did not reproduce in the
strict repeat and must not be relabelled as a USB failure.

## SAE/AMPE and secured transfer

`secure-20260812T121719Z.log` passed with both RTL8812AU peers:

- SAE accepted and AMPE decrypted at both peers;
- MFP, authentication, association, and authorization active;
- 20/20 unicast pings in both directions, bidirectional multicast, and
  reciprocal HWMP paths;
- a 32 MiB SHA-256-verified transfer in each direction, at 5,376,383 B/s
  root-to-peer and 7,405,297 B/s peer-to-root;
- zero kernel transport events.

The secured-test cleanup rebuilt the open MAC-based topology and exact DKMS
0.1.5 provenance passed afterward. Retained Pi artifacts are under
`/var/tmp/rtl8812au-mesh/mesh-churn/` and
`/var/tmp/rtl8812au-mesh/secure/`.

## Open 512 MiB transfer

The standalone open-mesh transfer (`transfer-20260812T121947Z.log`) completed
one 512 MiB SHA-256-verified transfer in each direction. Root-to-peer completed
in 102.71 seconds at 5,227,010 B/s; peer-to-root completed in 78.27 seconds at
6,858,876 B/s. Both output hashes matched the 512 MiB source, postflight HWMP
paths were present at both peers, and the full 199-second interval had zero
kernel transport events. The wrapper exit status was zero.

## Remaining scope

This does not close long-duration endurance, HT40/5 GHz, physical
re-enumeration, or the complete USB path-matrix gates.
