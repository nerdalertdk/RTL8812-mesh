# Session

## Current focus

Bootstrap and validate the standalone RTL8812AU mesh driver package.

## Current status

- Source imported from `/Users/michael/code/privat/rtw88` at base commit
  `a56bcd2`, including the current uncommitted mesh/USB fixes.
- The focused build produced exactly five modules against Pi kernel
  `6.12.47+rpt-rpi-v8`.
- DKMS package `rtl8812au-mesh/0.1.0` is installed; all five loaded module
  source versions match their artifacts in `updates/dkms`.
- The packaged driver passed the 2026-07-26 one-cycle open-mesh churn smoke:
  plink, bidirectional first contact, multicast, and HWMP paths all passed,
  with no USB errors reported since test start.
- A 2026-07-26 channels 1--13 HT20 sweep passed link, bidirectional unicast,
  and HWMP on every channel. It finished 12/13 because one peer-to-root
  multicast burst was not observed on channel 2; an alternating channel 1/2
  control then passed 10/10. No USB transport events occurred. The channel
  gate remains open until the intermittent multicast result is explained or
  repeated with two RTL8812AU radios.
- A 600-second channel-1 endurance run completed with 17/17 established state
  samples, 34/34 successful 10-packet ping batches, and 18/18 checksummed
  32 MiB transfers (576 MiB total). It recorded zero unavailable states,
  recovery windows, invalidations, transfer failures, or USB transport events.
  Pi temperature ranged from 78.880 to 80.828 C; `get_throttled=0xe0000`
  records historical under-voltage/throttling flags but no current low-bit
  throttle condition during the run.
- Synthetic RX submit fault injection consumed eight `-EPROTO` failures and
  restored all four RX slots (`success_mask=0xf`) with 40/40 pings in both
  directions. A post-fault run passed six checksummed 32 MiB transfers.
- Teardown with 99,981 synthetic failures still pending removed all five
  modules in 593 ms without a kernel warning/Oops/UAF signature. The production
  DKMS stack was restored, source-version verified, and the mesh re-established.
  Detailed evidence is in `tests/results/2026-07-26-rx-submit-eproto.md`.

## Known issues

- Secured payload validation is blocked until another stable RTL8812AU peer is
  available; RTL8192FU is retained only as an experimental open-mesh fixture.
- Original USB2 and independently powered-path endurance remain unvalidated.
- The current peer is RTL8192FU using `rtl8xxxu`; its intermittent multicast
  behavior cannot establish whether the remaining miss is in the RTL8192FU
  transmitter, RTL8812AU receiver, or the test transition timing.
