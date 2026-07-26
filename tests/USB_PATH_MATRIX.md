# Physical USB `-EPROTO` path matrix

## Purpose

Use repeated, controlled endurance runs to determine whether real RTL8812AU
`-EPROTO` (`-71`) failures follow the driver/adapter or the Pi USB power and
transport path. Synthetic injection proves driver recovery code, but cannot
answer this physical-causality question.

## Controls

Keep these identical for every matrix row:

- the same RTL8812AU adapter, antenna orientation, peer, and physical spacing;
- the same Pi, kernel, firmware, DKMS package, mesh ID, channel, and bandwidth;
- the same power supply unless the row explicitly changes it;
- the same soak duration, poll rate, transfer size, and transfer interval;
- no unrelated USB device moves or high-load jobs during a run.

Record the adapter USB serial when available. If it has no serial, record its
VID:PID, permanent MAC, physical label, and a photograph or other unambiguous
identifier. A second RTL8812AU is a peer replacement, not a substitute for
holding the device-under-test constant across USB-path rows.

## Minimum matrix

| Row | RTL8812AU path | Pi supply | Purpose |
| --- | --- | --- | --- |
| A | direct Pi USB 3 | fixed known supply | current baseline |
| B | direct Pi USB 2 | same as A | controller/speed/path comparison |
| C | independently powered USB 3 hub | same as A | isolate downstream power |
| D | independently powered USB 2 hub or forced high-speed path | same as A | power-isolated USB2 comparison |

If any row records current under-voltage, over-current, or thermal invalidation,
repeat it after correcting that environmental fault. Do not count an invalid
row as driver evidence.

Run every valid row at least three times. A single clean or failed run is useful
observation, not causal separation.

## Pre-run record

Capture immediately before each run:

```sh
date --iso-8601=seconds
uname -a
/sbin/dkms status rtl8812au-mesh
/sbin/modinfo -n rtw_usb
/sbin/modinfo -F srcversion rtw_usb
cat /sys/module/rtw_usb/srcversion
lsusb
lsusb -t
vcgencmd get_throttled
vcgencmd measure_temp
```

Also record:

- matrix row and repetition number;
- Pi power-supply make/rating;
- hub make/model, its supply rating, and upstream cable for powered rows;
- physical Pi port and negotiated speed;
- adapter identity and permanent MAC;
- kernel boot ID (`cat /proc/sys/kernel/random/boot_id`).

Clear historical Raspberry Pi throttle evidence only by rebooting; do not
reinterpret a nonzero historical mask as a current fault. Preserve both the
pre-run and post-run masks.

## Workload

Use `pi_mesh_soak.sh` for eight hours or longer. The production decision run
should use two stable RTL8812AU radios; the RTL8192FU fixture can still expose
USB transport faults but cannot close mesh interoperability gates.

Each valid run must include:

- continuous bidirectional ping batches;
- periodic bidirectional checksummed transfers;
- established plink and nonempty HWMP path tables at every state sample;
- temperature, throttle flags, and USB topology in the summary;
- complete kernel transport events from start through completion.

After the soak, transfer one 512 MiB deterministic file in each direction and
verify SHA-256 at the receiver. Keep those results separate from the periodic
small-transfer count.

## Event classification

Classify each observed event before drawing a conclusion:

- `RX completion`: `recoverable RX URB error -71`; driver retained the device
  and resubmitted reception.
- `RX submission`: `transient RX URB submit error -71; retrying`; submission
  failed before USB core accepted the URB.
- `control read`: register read recovered after multiple attempts or exhausted
  its bounded retry count.
- `control write`: register write failed; never infer that retrying it is safe.
- `transport reset/disconnect`: USB core reset or removed the device; correlate
  with recovery-service timing and mesh outage.
- `power/topology`: under-voltage, over-current, link-speed change, hub reset,
  or another device on the same tree disconnecting near the event.

For every `-71`, retain at least 30 seconds of kernel log before and 120 seconds
after the first event, plus the corresponding soak log interval.

## Decision rules

- Failures that follow the same adapter across direct and independently powered
  paths, with clean power/thermal evidence, support a driver/adapter cause.
- Failures confined to direct Pi paths and absent across repeated powered-hub
  runs support downstream power or Pi-port topology as the cause.
- Failures confined to one negotiated speed/controller path support a USB
  transport compatibility issue, not an 802.11s-specific conclusion.
- Simultaneous errors on unrelated devices or power flags near the event make
  the row environmental evidence.
- A driver claim requires recurrence with the same kernel event class and a
  reproducible workload trigger. Absence of failure is not proof after only one
  run.

Do not close the physical `-71` gate until every minimum row has three valid
runs or until one row provides a repeatable causal trigger that is independently
confirmed after changing only that row's USB-path variable.
