# TODO

## Pending hardware gates

- [ ] Run channels 1--13 HT20 sweep.
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
