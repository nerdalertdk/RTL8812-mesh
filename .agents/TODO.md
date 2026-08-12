# TODO

## In progress

- [ ] Confirm and isolate production 0.1.5 multicast loss on USB hub branch
  `1-1.2`: post-swap runs delivered 395/400 then 381/400 into `…0d:8b` on
  `1-1.2`, versus 400/400 then 398/400 into `…08:c1` on `1-1.4`, with no
  transport event. Test a direct or independently powered path before closing
  multicast qualification or attributing a driver fault.
- [ ] Restore exact production 0.1.5 and repeat strict open churn, HWMP,
  multicast, SAE/AMPE, checksummed transfer, and bounded endurance gates.

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
