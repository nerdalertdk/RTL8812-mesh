# DKMS 0.1.5 bounded mesh soak

## Scope

Two RTL8812AU mesh points on the Raspberry Pi, using the validated USB
branches `1-1.1` and `1-1.4`, ran the installed, provenance-checked DKMS
0.1.5 package in open 2.4 GHz HT20 mesh mode.  The run used a 30-minute
duration, 30-second state polling, bidirectional ten-ping batches, and a
checksum-verified 10 MiB transfer in each direction every 600 seconds.

## Exact result

Run `20260812T122508Z` completed at `2026-08-12T12:55:14Z` with exit status
zero.

```
duration_requested_seconds=1800
completed=1
state_total=37
state_established=37
state_unavailable=0
ping_batches_total=74
ping_batches_failed=0
transfers_ok=6
transfers_failed=0
recovery_windows=0
invalidations=0
kernel_transport_events=0
temperature_samples=37
temperature_min_millic=70114
temperature_max_millic=74010
throttled=0x0
```

Both adapters were visible as `rtw_8812au` devices below the Pi USB 2.0 hub,
on distinct hub ports.  This is clean bounded-endurance evidence for the
installed 0.1.5 package and validated topology only; it is not qualification
of the distinct, uninstalled 0.1.6 candidate or of the full physical USB-path
matrix.
