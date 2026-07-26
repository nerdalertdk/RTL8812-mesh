# TODO

## In progress

- [ ] Complete and review the production eight-hour soak started
  2026-07-26 15:29 CEST (expected completion 23:29 CEST).
- [ ] Rebuild the new `CONFIG_MAC80211_MESH` capability guard against the Pi
  kernel after the soak releases the thermally constrained test host.
- [ ] Build-test the read-only control-transfer injector filter after the soak.

## Pending hardware gates

- [ ] Run channels 1--13 HT20 sweep.
- [ ] Run the sender/receiver multicast probe after the active soak to localize
  the intermittent mixed-adapter multicast miss.
- [ ] Validate secured traffic with a second stable RTL8812AU.
- [ ] Repeat original USB2 and independently powered-path endurance tests.
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
