# TODO

## Parked non-mesh follow-up

- [ ] Independently decide whether generic USB-path, physical re-enumeration,
  and antenna-capability work should become a separate driver-hardening effort.
  Do not run or extend these gates as part of the mesh-support goal unless a
  reproduced mesh failure requires them.

## Completed

- [x] Complete the exact 0.1.6 strict 30-minute mesh-endurance gate: 37/37
  established states, 74/74 lossless batches, 12/12 checksummed transfers,
  and zero recovery, invalidation, transport event, or throttle condition.

- [x] Run the exact-source `W=1`/DKMS build-only gate, install, load, and
  provenance-check production DKMS 0.1.5 on the exact Raspberry Pi kernel.
- [x] Pass current-source 0.1.6 serialized 2.4 GHz HT20 channel sweep 13/13,
  including fresh peering, cold traffic, multicast reachability, HWMP, and a
  clean kernel interval.
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
- [x] Requalify exact 0.1.6 SAE/AMPE and bidirectional 32 MiB checksum
  transfer on the validated HT20 topology, including provenance-safe recovery.
- [x] Validate strict churn, checksummed 512 MiB transfers, and prior-build
  bounded/eight-hour endurance.
- [x] Requalify exact 0.1.6 open bidirectional 512 MiB checksum transfer on
  the validated HT20 topology with reciprocal HWMP and clean transport interval.
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
