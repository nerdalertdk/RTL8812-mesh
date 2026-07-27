# Eight-hour soak and later power-cycle evidence — 2026-07-27

## Completed endurance run

Run `20260726T190704Z` began at 2026-07-26 19:07:04 UTC and wrote its explicit
completion marker and summary at 2026-07-27 03:07:23 UTC. The later power loss
therefore did not interrupt or invalidate the timed run.

- requested duration: 28,800 seconds;
- mesh state: 597/597 bilateral `ESTAB`, with HWMP paths at both peers;
- traffic: 1,194/1,194 successful ten-packet ping batches;
- integrity: 16/16 successful checksummed 10 MiB transfers;
- recovery windows and invalidations: zero;
- kernel USB transport events during the measured interval: zero;
- temperature: 75.471--80.341 C;
- power flag: `0xe0000` in every sample.

The low bits of `0xe0000` are clear, so no power/throttle condition was current
at a sample. Its high bits are sticky history indicating that undervoltage,
frequency capping, and throttling had occurred since boot; the run cannot date
those earlier events and therefore does not count as clean power-path evidence.

Durable Pi evidence digests:

```text
60c2c89f25dfb2d0224f336455d220e3f2f0f41d2b157c00fefc16f3bf338346  soak-20260726T190704Z.log
6deb16e89da09af63e74d702a73ae1c022550313614f8d2c783b360d8731a891  summary-20260726T190704Z.log
```

## Power-cycle diagnostic

The next recorded boot began more than five hours after soak completion. DKMS
0.1.2 loaded all five modules with installed and loaded `srcversion` values
matching, and RTL8812AU returned on the direct 5 Gb/s path. The experimental
RTL8192FU peer returned to the distribution `rtl8xxxu`, which advertises only
managed, AP/AP-VLAN, and monitor modes. It does not advertise mesh point.

The recovery helper moved that peer into `meshpeer`, configured RTL8812AU as a
mesh point, then failed ten times with `-EOPNOTSUPP` while attempting to change
RTL8192FU from managed to mesh. This is a non-persistent experimental-peer
module limitation, not evidence of an RTL8812AU mesh regression. Recovery now
preflights mesh capability before topology mutation and exits 78; systemd does
not restart that environmental failure. A live post-boot preflight returned 78
with `peer wiphy phy1 driver rtl8xxxu does not advertise mesh-point mode`; the
combined root/peer `iw info` SHA-256 was identical before and after
(`235cd99d9a93564f718567b80cb00af5e009e470f2a56cd931772f6bdfd72f30`).

During boot RTL8812AU first appeared on USB2. The old-chip USB3 mode-switch
path intentionally wrote `REG_SYS_PW_CTRL + 1` (`0x5`) to disconnect the
device. That control write returned `-EPROTO`, immediately followed by the
expected disconnect and successful USB3 re-enumeration. Source 0.1.3 classifies
only this narrowly identified mode-switch disconnect as expected, keeping it
out of generic control-error counters and diagnostics. Other `-EPROTO` writes
remain errors and are never retried.
