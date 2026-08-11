# Session

## Current focus

Make RTL8812AU native IEEE 802.11s support correct, robust, reproducible on
Debian, and suitable for upstream Linux submission. Production DKMS 0.1.5 is
now exact-kernel built, loaded, provenance-checked, and mesh-smoke-checked; the
immediate work is deterministic disposable TX error/teardown evidence, then
the IEEE 802.11s behavioral and endurance regressions with two RTL8812AU peers.

## Current source

- Production source fixes standalone RTL8812AU USB mesh admission, mesh group
  queue selection, mesh software crypto, USB control serialization/retry, RX
  capacity recovery, TX ownership/error reporting, and TX URB teardown.
- The package boundary is exactly `rtw_core`, `rtw_usb`, `rtw_88xxa`,
  `rtw_8812a`, and `rtw_8812au`.
- Downstream eight-patch and pinned wireless-next eight-patch series reproduce
  the validated four-file final source exactly.
- A separate pinned current-mainline TX-only series captures only TX changes
  not already present in its target tree.
- Repository static checks and stored production patches pass strict validation.

## Behavioral evidence

- Two RTL8812AU peers established open bilateral `ESTAB` links and reciprocal
  HWMP paths across channels 1--13 HT20.
- Strict 20-cycle churn, bidirectional cold first contact, and checksummed
  512 MiB transfers passed on DKMS 0.1.4.
- Sender-captured multicast delivered 399/400 and 400/400 frames with no USB
  event; the separate churn reachability gate passed 20/20.
- SAE/AMPE passed peer-specific SAE acceptance, decrypted AMPE, authorization,
  MFP, bidirectional unicast/multicast, reciprocal HWMP, and checksummed payloads
  with two RTL8812AU peers.
- Prior source versions passed bounded and eight-hour endurance. Current-source
  0.1.5 behavioral regression remains required after TX changes.
- The final symmetric DKMS 0.1.4 eight-hour run completed 597/597 bilateral
  states, 1,194/1,194 ping batches, and 16/16 checksummed transfers with zero
  recovery, invalidation, or kernel transport event. A later manual Pi power
  removal occurred outside the completed interval. The queued final transfer
  and 0.1.5 build did not run because the finalizer consumed the wrong summary
  filename; the repository contract and an offline fixture now cover it.
- After the later manual power cycle, exact 0.1.4 provenance passed, normal
  userspace test infrastructure restored bilateral `ESTAB`/HWMP, and the
  deferred 512 MiB transfer passed both directions at 4.42 and 4.72 MB/s with
  matching SHA-256 and zero kernel transport/power events. Current power state
  was clean at `get_throttled=0x0`.

## USB evidence

- Read-only injected control `-EPROTO` exercised bounded retry and recovery.
- Eight injected RX completion/submit failures exceeded the four-URB pool and
  recovered all slots without losing the peer.
- RX teardown with retry work pending completed without warning, Oops, UAF, or
  post-free work evidence.
- Version-pinned udev/systemd test infrastructure reconstructed both mesh
  interfaces, addressing, peering, traffic, and HWMP after controlled rebind;
  it is not part of the proposed upstream driver patches.
- A previous simultaneous physical disconnect involved both USB radios and
  shared-path power/topology evidence. It is not evidence of an isolated
  RTL8812AU mesh failure; the controlled physical USB matrix remains open.

## Source 0.1.5 pending evidence

- Deterministic generic TX submission rejection, populated aggregate rejection
  with post-cleanup proof, and completion `-EPROTO` with an exact-count marker
  emitted only after the production no-false-ACK status routine returns. These
  passed in the disposable build; see
  `tests/results/2026-08-11-usb-tx-fault-injection.md`.
- Unbind while a selected TX callback is active, requiring zero anchored URBs
  and callbacks after synchronous kill and no lifetime fault signature. The
  disposable kernel-side test proved that USB core defers driver remove until
  the active callback returns, then observed zero/zero post-kill state and
  bounded rebind; see
  `tests/results/2026-08-11-usb-tx-teardown-serialization.md`.
- Production reload followed by open churn, multicast, HWMP, SAE/AMPE,
  checksummed transfer, and endurance regression.
- Direct and independently powered USB2/USB3 physical-path repetitions.

## Current regression

- Production 0.1.5 passed strict 20-cycle open mesh churn, cold first contact,
  binary multicast, reciprocal HWMP, and zero USB-error checks. Two subsequent
  sender-captured multicast probes failed the 99% threshold: root-to-peer
  delivered 400/400 then 398/400 while peer-to-root delivered 393/400 then
  390/400, each with zero kernel transport event. This blocks multicast
  qualification; see
  `tests/results/2026-08-11-production-multicast-regression.md`.

## Source 0.1.5 completed evidence

- Exact-current flat-source `W=1` and DKMS build-only qualification passed for
  `6.12.47+rpt-rpi-v8` with exactly five modules and zero diagnostics.
- DKMS 0.1.5 was installed and loaded from `updates/dkms`; all five
  installed/loaded hashes and `srcversion` fields matched exactly.
- Version-pinned recovery rebuilt two RTL8812AU mesh points with bilateral
  `ESTAB`, reciprocal HWMP, and lossless five-packet traffic in both directions.
- The activation interval included an un-attributable Pi reboot with no
  persistent prior journal and a historical soft-temperature bit.  It is not
  physical USB qualification evidence; see
  `tests/results/2026-08-11-dkms-0.1.5-build-load.md`.

## Test policy

- Serialize every mutating hardware test with
  `/run/lock/rtw88-mesh-test.lock`.
- Resolve radios by permanent MAC rather than unstable netdev names.
- Require exact installed/loaded module provenance before topology mutation.
- Treat exit 0 as a clean functional and kernel interval, exit 4 as requiring
  transport-event review, and provenance/environment failures as invalid
  evidence rather than driver failures.
- Keep synthetic fault evidence distinct from cable, power, hub, adapter, and
  host-controller evidence.
