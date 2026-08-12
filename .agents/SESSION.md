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
- RTL8812AU no longer advertises nl80211 per-chain antenna selection because
  its chip operation is absent; fixed 2T2R operation remains unchanged.
- The deployed evidence package is 0.1.5. The current source has the later
  antenna-capability correction and is now versioned as the unbuilt 0.1.6
  candidate so provenance cannot conflate it with 0.1.5.
- The package boundary is exactly `rtw_core`, `rtw_usb`, `rtw_88xxa`,
  `rtw_8812a`, and `rtw_8812au`.
- Downstream nine-patch and pinned wireless-next nine-patch series reproduce
  the validated four-file final source exactly.
- A separate pinned current-mainline TX-only series captures only TX changes
  not already present in its target tree.
- Repository static checks and stored production patches pass strict validation.
- DKMS 0.1.6 passes the exact-kernel `W=1` and build-only gate (five modules,
  zero diagnostics) and is installed but not runtime-qualified.  During the
  subsequent attempted transition while 0.1.5 was still loaded, `ip link set
  down` after mesh leave triggered a mac80211 `ieee80211_do_stop` warning and
  left the `1-1.1` adapter USB-bound without a PHY/netdev.  This invalidates
  the transition interval; see
  `tests/results/2026-08-12-reload-warning-incident.md`.
- A safer USB-unbind/module-reload/USB-rebind procedure then loaded exact DKMS
  0.1.6 provenance, rebuilt bilateral mesh/HWMP, and completed a 32 MiB
  checksum transfer with no fresh warning or transport event. Both PHYs now
  expose zero selectable antenna masks, as intended. Two 400-frame group
  probes nevertheless delivered 391/400 then 394/400 root-to-peer to
  `1-1.1`, while reverse delivery was 400/400 and no transport event occurred.
  A capture-valid 5 Hz diagnostic also delivered only 191/200 root-to-peer
  while reverse delivery was 200/200. This is a failing 0.1.6 group-traffic
  gate. The later adapter swap localizes its dominant loss to physical adapter
  `…08:c1` or its antenna; see
  `tests/results/2026-08-12-dkms-0.1.6-build-load-smoke.md`.
- A physical port swap then isolated the severe group-frame loss to physical
  unit `fc:22:1c:30:08:c1` or its attached antenna: its sender capture fell
  from 391/400 and 394/400 on `1-1.4` to 333/400 on `1-1.1`; the other unit
  delivered 395/400 from the swapped `1-1.4` port. The clean post-swap probe
  had zero transport event. This rules out both tested USB branches as the
  primary cause but requires an antenna exchange or third adapter to separate
  card from antenna; see
  `tests/results/2026-08-12-adapter-swap-multicast-isolation.md`.

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
  390/400, each with zero kernel transport event. A 10 dBm control delivered
  400/400 root-to-peer and 394/400 peer-to-root, so near-field output power
  alone does not explain the loss. A valid physical-role reversal then delivered
  393/400 to `fc:22:1c:30:08:c1` / USB path `1-1.2` but 399/400 to the other
  adapter, excluding root-namespace role and locating the issue to that
  receiver-specific physical path. After physically swapping the adapters, the
  first complete 400-frame probe delivered 395/400 into `…0d:8b` now on USB
  branch `1-1.2`, but 400/400 into `…08:c1` now on `1-1.4`; the independent
  repeat delivered 381/400 and 398/400 respectively. Neither had a transport
  event or throttle bit. Moving `…0d:8b` again to `1-1.1` while retaining
  `…08:c1` on `1-1.4` then passed 399/400 and 400/400 with zero transport
  event. This rules out a stable individual-adapter or namespace cause and
  strongly localizes the issue to the `1-1.2` shared physical/RF/hub
  environment, though it does not prove a receive-only failure. The exposed
  `rx_dropped` statistic rises symmetrically and is not a valid attribution
  counter. One control does not close the direct/powered USB matrix; see
  `tests/results/2026-08-11-production-multicast-regression.md`.

## Source 0.1.5 completed evidence

- Exact-current flat-source `W=1` and DKMS build-only qualification passed for
  `6.12.47+rpt-rpi-v8` with exactly five modules and zero diagnostics.
- DKMS 0.1.5 was installed and loaded from `updates/dkms`; all five
  installed/loaded hashes and `srcversion` fields matched exactly.
- Version-pinned recovery rebuilt two RTL8812AU mesh points with bilateral
  `ESTAB`, reciprocal HWMP, and lossless five-packet traffic in both directions.
- On the validated `1-1.1`/`1-1.4` topology, a retained strict 20-cycle open
  churn repeat passed bilateral peering, cold contact, multicast, and HWMP with
  zero USB event. A current-source SAE/AMPE run passed peer-specific security,
  MFP, authorization, bidirectional unicast/multicast/HWMP, and 32 MiB
  checksummed transfers in both directions, then recovered the open topology.
- A standalone current-source 512 MiB open transfer passed SHA-256 in both
  directions at 5.23 and 6.86 MB/s with reciprocal postflight HWMP and zero
  kernel transport event.
- A current-source DKMS 0.1.5 bounded 30-minute soak completed 37/37
  established-state samples, 74/74 ping batches, and six checksum-verified
  transfers with zero recovery, invalidation, transport event, or throttling;
  see `tests/results/2026-08-12-production-0.1.5-bounded-soak.md`.
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
