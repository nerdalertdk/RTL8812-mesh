# TODO

## In progress

- [ ] Build, install, provenance-check, and regress the distinct 0.1.6 package
  containing the correction that stops unsupported per-chain antenna selection
  from being advertised.
- [ ] Separate the multicast fault that follows physical adapter `…08:c1`
  across the `1-1.4`/`1-1.1` port swap from its attached antenna: exchange
  detachable antennas or test a known-good third RTL8812AU. The A/B swap
  rules out both tested USB branches as the primary cause.
- [ ] Complete the physical USB-path matrix after separating the `…08:c1`
  adapter from its antenna. The latest direct A/B swap between `1-1.1` and
  `1-1.4` shows those two branches are not the primary cause of the severe
  loss; repeat with a powered hub/direct paths only after the hardware source
  is known.
- [ ] Complete a thermally clean long-duration current-source endurance gate.
  The 30-minute bounded 0.1.5 soak now passes on `1-1.1`/`1-1.4`; strict open
  churn/HWMP/multicast, SAE/AMPE plus 32 MiB secured transfer, and a 512 MiB
  bidirectional checksum-verified open transfer also pass there.
- [ ] Qualify 2.4 GHz HT40 and 5 GHz HT20/HT40 separately from the core
  2.4 GHz HT20 release profile, subject to the active regulatory domain and
  DFS requirements. 0.1.6 passed a non-DFS channel-149 5 GHz HT20 smoke;
  its quantitative multicast, security, transfer, and multi-cycle gates remain;
  a channel-149/153 5 GHz HT40+ smoke also passes but is not full qualification.

## Pending hardware gates

- [ ] Complete three valid repetitions of each direct/powered USB2/USB3 row in
  `tests/USB_PATH_MATRIX.md`.
- [ ] Complete a thermally clean long-duration current-source endurance run.
- [ ] Validate physical unplug/re-enumeration reconstruction independently from
  synthetic control, RX, and TX failures.

## Completed

- [x] Run the exact-source `W=1`/DKMS build-only gate, install, load, and
  provenance-check production DKMS 0.1.5 on the exact Raspberry Pi kernel.
- [x] Pass the exact 0.1.6 serialized mesh leave/down/up lifecycle gate for
  20/20 cycles with peer-table quiescence, cold traffic, multicast, HWMP, and
  no warning or transport event.
- [x] Prove disposable 0.1.5 TX pre-submit ownership, forced aggregate cleanup,
  and post-status no-false-ACK behavior with deterministic `-EPROTO` faults.
- [x] Prove Linux USB-core serialization of active TX completion before driver
  remove, plus bounded disposable unbind/rebind and post-kill quiescence.
- [x] Package only the five required RTL8812AU/shared rtw88 modules and firmware.
- [x] Add RTL8812AU USB-only standalone mesh-point capability advertisement.
- [x] Validate open peering, reciprocal HWMP, bidirectional unicast, broadcast,
  multicast, and channels 1--13 HT20 with two RTL8812AU peers.
- [x] Validate symmetric SAE/AMPE, protected traffic, group traffic, and HWMP
  using the mesh software-crypto fallback.
- [x] Validate strict churn, checksummed 512 MiB transfers, and prior-build
  bounded/eight-hour endurance.
- [x] Add bounded USB control-read retry, RX completion resubmission, RX submit
  retry, and synchronized RX teardown.
- [x] Add automatic version/provenance-safe topology reconstruction after USB
  rebind.
- [x] Correct aggregate/original TX skb ownership, failed-submission cleanup,
  completion error reporting, and TX URB teardown anchoring in source 0.1.5.
- [x] Materialize and verify downstream, current wireless-next, and TX-only
  upstream patch series with exact baseline/final hashes.
- [x] Make all hardware harnesses serialized, provenance-aware, and explicit
  about workload, transport-event, and invalid-evidence outcomes.
