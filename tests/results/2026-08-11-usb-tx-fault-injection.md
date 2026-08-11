# RTL8812AU TX fault-injection result — 2026-08-11

## Result

The disposable `0.1.5-tx-agg-test` build passed all three deterministic TX
failure phases on two RTL8812AU adapters. The exact production DKMS 0.1.5
stack was reinstalled and provenance-checked immediately afterward.

- Input source manifest:
  `e8115c8d0deb50f252fb91a0ca846fa74fd20c9d7ce16d3cc9b41ab49e8d0da5`.
- Injection-patch SHA-256:
  `907108e5c79dad9222f223761459fd00168917d79a30934eea91a224c2e96d2d`.
- Exact-kernel disposable `W=1` and DKMS builds completed without warnings.
- Result log:
  `/var/tmp/rtl8812au-mesh/usb-tx-failure/tx-failure-20260811T202102Z.log`.
- Kernel interval:
  `/var/tmp/rtl8812au-mesh/usb-tx-failure/tx-failure-20260811T202102Z-kernel.log`.

| Phase | Requests | Remaining | Required marker | Observed |
| --- | ---: | ---: | --- | ---: |
| Pre-submit rejection | 8 | 0 | TX `-EPROTO` diagnostics | 8 |
| Aggregate rejection | 8 | 0 | rejection and post-cleanup | 8 / 8 |
| Completion status | 8 | 0 | post-status report | 8 |

The harness reported 24 expected synthetic `USB TX URB error -71` diagnostics,
positive nonduplicated per-adapter error counters, valid two-original aggregate
cleanup values, zero unexpected kernel events, bilateral traffic, bilateral
`ESTAB`, and reciprocal HWMP paths.

RTL8812AU normally sets `usb_tx_agg_desc_num = 1`; a real multi-frame USB
aggregate is therefore not created by the normal device configuration. The
disposable patch raises only the temporary test limit to two while the
aggregate-injection counter is nonzero. This makes the driver-owned
aggregate-buffer/original-skb cleanup path observable without changing
production behavior or treating it as physical USB evidence.

## Teardown follow-up

The first teardown attempt did not prove a driver defect. USB removes a URB
from its anchor before invoking its completion callback, so the old harness
observed an empty anchor while its deliberately delayed callback was active.
It also classified the expected reset from its own controlled unbind as a
transport fault. The disposable patch now maintains an explicit active-callback
counter, and the harness records/excludes that one controlled reset. The
revised teardown build/run remains pending.
