# Upstream/static audit — 2026-07-26

## Scope

The production changes in `main.c`, `mac80211.c`, `usb.c`, and `usb.h` were
reviewed against Linux v6.12 and current mainline rtw88, then checked against
the exact Raspberry Pi target kernel (`6.12.47+rpt-rpi-v8`). Test-only fault
injection was excluded.

## Results

- An exact-kernel `W=1` build completed without a compiler warning.
- Linux v6.12 `scripts/checkpatch.pl --strict` reported 0 errors, 0 warnings,
  and 0 checks for the four-file production delta (373 lines checked).
- Mainline already accepts `NL80211_IFTYPE_MESH_POINT` in the rtw88 interface
  setup switch, but does not advertise mesh in `interface_modes`. The focused
  RTL8812AU USB capability gate therefore exposes an existing dormant path
  rather than inventing a parallel interface implementation.
- Mainline's receive filter handles `FIF_OTHER_BSS` and
  `FIF_BCN_PRBRESP_PROMISC` separately. The production driver deliberately
  clears both BSSID beacon/data filters while either flag is active. Hardware
  testing showed this is required to receive mesh peer beacons whose BSSID is
  not the local mesh interface BSSID.
- Mainline rtw88 USB still uses a process-wide static diagnostic limiter for
  control failures, does not reject short control transfers, and neither
  retries transient idempotent reads nor restores RX capacity after the
  recoverable URB failures handled by this package.
- The delayed RX resubmit worker is valid on the kernel's `WQ_BH` workqueue:
  it uses atomic allocation and non-sleeping submission/queue operations.
- A suspected partial-allocation cleanup issue was rejected after checking
  Linux v6.12 USB core: both `usb_kill_urb(NULL)` and `usb_free_urb(NULL)` are
  explicitly safe. No source change was made.

## Conclusion

No additional production defect was found, so DKMS remains at `0.1.2`.
Remaining release gates require physical evidence: secured operation and
symmetric multicast with a second stable RTL8812AU, plus the direct/powered
USB2/USB3 path matrix and final long-duration topology test.
