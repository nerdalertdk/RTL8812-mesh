# TODO

## In progress

- [ ] Build, install, and regression-test DKMS `0.1.3` after the active soak,
  including control-read injection and concurrency-safe unload/reload.
- [x] Build, install, and regression-test DKMS `0.1.2` with the audited mesh
  `DISABLE_KEY` contract and RX teardown retry-race fix.
- [ ] Deploy and run the hardened recovery helper after the active soak, then
  verify bilateral traffic/HWMP and exact five-module provenance.
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
- [x] Run the sender/receiver multicast probe after the active soak to localize
  the intermittent mixed-adapter multicast miss.
- [ ] Compare multicast delivery with two stable RTL8812AU radios; the mixed
  RTL8812AU/RTL8192FU probe delivered 797/800 captured frames bidirectionally.
- [x] Run the bidirectional 512 MiB SHA-256 transfer gate after the active soak.
- [ ] Validate secured traffic with a second stable RTL8812AU.
- [ ] Complete three valid repetitions of each row in
  `tests/USB_PATH_MATRIX.md` (direct USB3/USB2 and powered USB3/USB2 paths).
- [ ] Extend bounded endurance to a long unattended run.

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
