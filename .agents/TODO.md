# TODO

## In progress

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
