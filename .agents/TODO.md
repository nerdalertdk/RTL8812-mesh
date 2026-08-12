# TODO

## In progress

- [ ] Complete the physical USB-path matrix. The multicast control now passes
  399/400 into `…0d:8b` on `1-1.1` and 400/400 into `…08:c1` on `1-1.4`, while
  the `1-1.2` post-swap runs delivered 395/400 then 381/400 into `…0d:8b`.
  This strongly localizes the issue to `1-1.2`; repeat across direct/powered
  paths before closing qualification or attributing a driver fault.
- [ ] Complete current-source 0.1.5 bounded/long-duration endurance gates.
  Strict open churn/HWMP/multicast, SAE/AMPE plus 32 MiB secured transfer, and
  a 512 MiB bidirectional checksum-verified open transfer now pass on
  `1-1.1`/`1-1.4`.
- [ ] Qualify 2.4 GHz HT40 and 5 GHz HT20/HT40 separately from the core
  2.4 GHz HT20 release profile, subject to the active regulatory domain and
  DFS requirements.

## Pending hardware gates

- [ ] Complete three valid repetitions of each direct/powered USB2/USB3 row in
  `tests/USB_PATH_MATRIX.md`.
- [ ] Complete a thermally clean long-duration current-source endurance run.
- [ ] Validate physical unplug/re-enumeration reconstruction independently from
  synthetic control, RX, and TX failures.

## Completed

- [x] Run the exact-source `W=1`/DKMS build-only gate, install, load, and
  provenance-check production DKMS 0.1.5 on the exact Raspberry Pi kernel.
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
