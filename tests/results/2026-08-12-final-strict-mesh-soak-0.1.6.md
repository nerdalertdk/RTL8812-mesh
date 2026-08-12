# Final strict mesh soak, DKMS 0.1.6

Date: 2026-08-12

## Profile

- two RTL8812AU adapters: `fc:22:1c:30:08:c1` and `fc:22:1c:30:0d:8b`;
- isolated open IEEE 802.11s mesh, 2.4 GHz HT20;
- exact installed DKMS 0.1.6 five-module provenance;
- 1,800 seconds, sampled every 30 seconds;
- strict lossless ten-reply ICMP batches in both directions;
- checksum-verified 10 MiB transfers in both directions every 300 seconds.

## Result

The run completed at `2026-08-12T17:01:31Z` with no recovery or invalid
evidence:

- 37/37 mesh-state samples were bilateral `ESTAB`, with reciprocal paths;
- 74/74 directional ping batches received all ten requested replies;
- 12/12 transfers had matching SHA-256 hashes;
- zero recovery windows, invalidations, and scoped kernel USB transport events;
- temperatures ranged from 73.036 to 75.958 C;
- `vcgencmd get_throttled` remained `0x0` throughout the run.

Both RTL8812AU devices were connected through separate ports of the Pi's
internal USB2 hub. This closes the current-source bounded mesh-endurance gate
for that validated topology; it does not establish independently powered
physical USB-path attribution.
