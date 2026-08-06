# Pinned Linux-mainline USB TX series

This directory contains the TX-only upstream form of downstream patches 7/8.
It is based on Linux commit
`315f4bd234b3b8a3ed3a71fd4c53b110cf373720` as inspected on 2026-08-06.

Current mainline purges the TX-status queue after synchronous TX URB submission
failure and frees reserved-page/H2C skbs. However, its synthetic aggregate
transfer skb is incorrectly mixed into that mac80211-owned status queue. The
two patches here add the missing behavior:

1. separate the driver-owned aggregate transfer buffer from original mac80211
   frames, account and diagnose TX submission/completion errors, report failed
   completions without ACK, avoid a firmware-report wait, and continue draining
   frames already queued after a synchronous submission failure;
2. anchor submitted TX URBs and synchronously quiesce callbacks after draining
   the TX producer during teardown.

`baseline/usb.c` and `baseline/usb.h` are the exact
`GPL-2.0 OR BSD-3-Clause` rtw88 files from the pinned Linux commit. They make
verification independent of a moving network branch; their SHA-256 values and
the two final patched hashes are enforced by
`scripts/check-mainline-tx-series.sh`.

The stored mail uses a neutral privacy identity and intentionally has no
`Signed-off-by`. Before submission, apply the patches to the intended current
tree, rerun review/build/hardware evidence, regenerate mail with the real
submitter identity, and add the submitter's DCO sign-off.
