# Strict mesh-soak smoke, DKMS 0.1.6

Date: 2026-08-12

## Purpose

Validate the corrected mesh-soak ping accounting.  The harness now treats a
partial ICMP batch as a workload failure instead of accepting the success exit
status that `ping` returns after receiving only some replies.

## Profile

- two RTL8812AU adapters (`fc:22:1c:30:08:c1` and `fc:22:1c:30:0d:8b`);
- open IEEE 802.11s mesh, 2.4 GHz HT20;
- bounded duration: 360 seconds; polling interval: 30 seconds;
- checksum-verified 10 MiB transfers every 300 seconds.

## Result

The run completed cleanly:

- 8/8 established mesh-state samples;
- 16/16 directional batches received all 10 requested replies;
- 4/4 transfers completed with matching SHA-256;
- zero recovery windows, invalidations, and kernel transport events;
- temperature range: 73.036--75.471 C;
- no active or newly latched Raspberry Pi power condition (the pre-existing
  historical `get_throttled=0xe0000` bits were retained as context only).

This confirms the stricter harness runs correctly on the current mesh. It is a
short smoke result and does not close the long-duration mesh endurance gate.
