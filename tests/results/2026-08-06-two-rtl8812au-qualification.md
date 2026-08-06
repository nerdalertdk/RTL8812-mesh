# Two-RTL8812AU qualification — 2026-08-06

## Fixture

- Debian 13.1 ARM64 on Raspberry Pi 4, kernel `6.12.47+rpt-rpi-v8`.
- Two `0bda:8812` adapters, one at USB3 `5000M` and one at USB2 `480M`; both
  used `rtw_8812au` and separate PHYs advertising `mesh point`.
- DKMS 0.1.4 loaded all five expected modules with exact installed/loaded
  `srcversion` matches.
- 2.4 GHz channel 1, HT20. Adapter MAC addresses are intentionally omitted.

## Open mesh

The recovery helper established bilateral `ESTAB`, traffic, and reciprocal
HWMP paths using `rtw_8812au` on both sides.

Two initial 20-cycle churn runs each passed all joins, plinks, cold unicast,
and HWMP checks, but each lost one root-to-peer single-frame multicast probe.
There were no USB events. The sender-captured quantitative multicast test then
measured:

- root to peer: 399/400 delivered (99.75%);
- peer to root: 400/400 delivered (100%);
- sender evidence: complete, 400/400 in both directions;
- kernel transport events: zero.

Because 802.11 multicast is unacknowledged, a one-frame reachability gate was
statistically inconsistent with the separate >=99% loss criterion. Churn now
sends three frames and requires one observed frame, matching the secured and
channel gates; quantitative loss remains a separate sender-captured gate. The
revised strict 20-cycle run passed 20/20 joins, plinks, cold contacts,
multicast reachability in both directions, and reciprocal HWMP paths, with
117--132 ms plink times and zero USB events.

## Integrity

One 512 MiB random source was transferred in both directions. Both received
copies matched the source SHA-256:

- root to peer: 3,965,687 B/s;
- peer to root: 5,137,343 B/s;
- postflight HWMP paths: one at each peer;
- kernel transport events: zero.

## SAE/AMPE

Both RTL8812AU peers completed SAE and AMPE. `wpa_supplicant` 2.10 reports
`key_mgmt=UNKNOWN` in `STATUS` for a completed mesh group, so the harness now
requires `COMPLETED`, configured SAE, peer-specific SAE acceptance, decrypted
AMPE, bilateral authorization/MFP, traffic, multicast, HWMP, and checksummed
payloads instead of trusting that broken summary field.

The gate passed 20/20 pings in each direction, multicast in each direction,
reciprocal HWMP, and a bidirectional 32 MiB transfer with matching SHA-256 at
5,279,758 B/s and 5,688,452 B/s. The secured interval contained zero USB
transport events, and the helper restored the validated open topology.

The first secured attempt also exposed a harness lifecycle fault: a namespace
supplicant survived because the recorded PID belonged to a shell-function
wrapper. The launcher now directly `exec`s `ip netns exec`, tracks the actual
supplicant, and fails closed if an exact test-specific process already exists.
A subsequent run left no orphan process and released the hardware lock.

## 2.4 GHz HT20 channel profile

Under the active DK regulatory domain, a fresh two-RTL8812AU sweep passed
channels 1--13. Every channel passed bilateral peering, three-packet cold
unicast in both directions, three-frame multicast reachability in both
directions, and reciprocal HWMP paths. The run completed 13/13 in 124 seconds,
contained zero USB transport events, and restored channel 1 afterward.

## USB and thermal observations

No `-EPROTO`/`-71`, reset, disconnect, control failure, or RX recovery event
occurred during these gates. `get_throttled=0x80000` records that the Pi soft
temperature limit occurred; no undervoltage bit was present. Temperatures near
the final tests were 79.8--80.8 C. Long endurance should use active cooling so
thermal limiting cannot confound USB-path attribution.

The hardened physical-path runner was then deployed and invoked as an isolated
row-A preflight with a separate non-matrix log root. It returned exit 2 with
`classification=invalid-pre-run-environment-state` and
`pre_throttled=0x80000`; no soak directory was created. This proves the current
thermal history cannot accidentally start or count as an attribution run.

## Remaining scope

This closes the symmetric open multicast, SAE/AMPE, and channels 1--13 HT20
gates. It does not close the four-row physical USB path matrix, powered-path
attribution, or a thermally clean long endurance run.
