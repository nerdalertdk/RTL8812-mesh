# TODO

## In progress

- [ ] Build and validate source DKMS 0.1.5 after the active soak. Inject USB TX
  submission/completion failures, prove traffic recovery and unload with
  anchored TX URBs pending, then repeat strict symmetric churn, a secured
  SAE/AMPE smoke, and the checksummed transfer gate.
- [ ] Complete the active eight-hour two-RTL8812AU functional endurance run
  started 2026-08-06 20:34 CEST. At the first hourly checkpoint it had passed
  77/77 bilateral states, 152/152 directional ping batches, and 4/4
  checksummed transfers with no USB or power event.
- [x] Make the four-file upstream production baseline reproducible with an
  exact-blob annotated tag and a deterministic verifier.
- [x] Materialize the eight logical upstream patches and verify that applying
  them in order reproduces all four validated production files byte-for-byte.
- [x] Make physical USB trials fail preflight when historical soft-temperature
  limiting is already set, preventing an undetectable thermal recurrence from
  being accepted as clean attribution evidence.

- [x] Build, install, and regression-test DKMS `0.1.4`, including exact
  five-module provenance, parallel control-read stress, control-read injection,
  strict churn, 512 MiB transfer, and controlled unload/reload.
- [x] Complete and review the bounded DKMS `0.1.4` soak: 12/12 bilateral
  established/HWMP samples, 24/24 ping batches, and 8/8 checksummed transfers
  passed with no recovery, invalidation, or kernel transport event.
- [x] Build, install, and regression-test DKMS `0.1.2` with the audited mesh
  `DISABLE_KEY` contract and RX teardown retry-race fix.
- [x] Deploy and run the hardened recovery helper; verify capability rejection
  before mutation and successful bilateral traffic/HWMP reconstruction after
  restoring the experimental peer's mesh-capable module.
- [x] Complete the final eight-hour DKMS 0.1.2 soak: 597/597 states,
  1,194/1,194 ping batches, and 16/16 checksummed transfers passed with no
  recovery window or USB transport event.
- [x] Complete and review the production soak started 2026-07-26 15:29 CEST
  and stopped on request at 20:00 CEST.
- [x] Build and install DKMS `0.1.1`, including the new
  `CONFIG_MAC80211_MESH` guard, after the soak releases the Pi.
- [x] Build-test the read-only control-transfer injector filter after the soak.

## Pending hardware gates

- [ ] Define the first deployment-country RF profiles from authoritative
  national sources, including channel, EIRP/PSD, and antenna constraints.
- [ ] Inventory candidate 30 dBm adapters: per-chain power, antenna ports,
  calibration, supply/current peaks, thermal behavior, and certification.
- [ ] Build a 100/250/500/750/1000 m bidirectional LOS field-test procedure
  based on `docs/RF_DEPLOYMENT.md`.
- [x] Run channels 1--13 HT20 sweep on DKMS 0.1.1; all channels passed
  peering, bidirectional unicast, and HWMP, followed by 10/10 complete
  channel-2 fresh-join repetitions.
- [x] Repeat channels 1--13 HT20 with two RTL8812AU peers; every channel passed
  bilateral peering, cold unicast, multicast, and reciprocal HWMP with no USB
  event.
- [x] Run the sender/receiver multicast probe after the active soak to localize
  the intermittent mixed-adapter multicast miss.
- [x] Compare multicast delivery with two stable RTL8812AU radios: complete
  sender capture, 399/400 and 400/400 delivered, and zero USB events.
- [x] Run the bidirectional 512 MiB SHA-256 transfer gate after the active soak.
- [x] Validate SAE/AMPE with two RTL8812AU peers, bilateral unicast,
  multicast, HWMP, and checksummed secured payloads.
- [ ] Complete three valid repetitions of each row in
  `tests/USB_PATH_MATRIX.md` (direct USB3/USB2 and powered USB3/USB2 paths).
- [ ] Retain direct USB3 as a regression profile while using USB2
  (`rtw_usb.switch_usb_mode=N`) as the 2.4 GHz deployment baseline.
- [ ] Extend bounded endurance to a long unattended run.
- [ ] Add active Pi cooling before the next long endurance/USB attribution
  run; symmetric qualification recorded historical soft-temperature limiting
  (`get_throttled=0x80000`) around 80 C.

## Completed

- [x] Copy only required RTL8812AU/shared rtw88 sources and firmware.
- [x] Exclude private signing material and unrelated chipset implementations.
- [x] Add focused manual and DKMS build metadata.
- [x] Build the standalone package against Pi kernel `6.12.47+rpt-rpi-v8`.
- [x] Install and provenance-check all five modules through DKMS.
- [x] Pass a one-cycle open-mesh churn smoke test from the standalone package.
- [x] Pass a 10-minute mixed-adapter endurance run with 17/17 established
  states, 34/34 ping batches, and 18/18 checksummed 32 MiB transfers.
- [x] Prove all four RX slots recover after eight synthetic `-EPROTO` submit
  failures and prove safe teardown while delayed retry work is active.
- [x] Complete exact-kernel `W=1`, strict checkpatch, and targeted upstream
  static review of the four-file production delta.
- [x] Harden the secured-mesh gate to verify the configured supplicant control
  socket, completed SAE state, bidirectional group delivery, HWMP, and optional
  checksummed payload transfer under the inherited hardware-test lock.
- [x] Make secured-test driver provenance safe across netdev renaming.
- [x] Add run-ID-aware soak monitoring that cannot report a stale summary.
- [x] Add a serialized physical USB matrix trial runner with provenance,
  summary validation, final transfer, kernel journal, and power invalidation.
- [x] Make timed soak exit status reflect its validated summary rather than
  unconditional loop completion.
- [x] Give multicast probing explicit sender-validity, delivery, provenance,
  and transport-event release outcomes.
- [x] Propagate peer provenance and transport-event review outcomes through
  churn, channel-sweep, and checksummed-transfer gates.
- [x] Require the shared `flock` in every hardware test instead of silently
  permitting unserialized execution; fix churn peer provenance preflight.
- [x] Make soak verdicts distinguish clean completion, workload failure, and a
  functionally recovered transport event without skipping the matrix's final
  integrity transfer.
