# USB control-buffer lifetime audit — 2026-07-26

## Finding

rtw88 USB selects register-transfer storage from a 128-entry rotating buffer
under `usb_lock`, then releases the spinlock before calling
`usb_control_msg()`. The lock therefore protects the index but not the selected
buffer's lifetime. A wrap after 128 overlapping operations can alias an
in-flight transfer. Bounded read retries increase the reservation interval to
roughly three seconds and make lifetime ownership more important.

Linux v6.12 documents `usb_control_msg()` as task-context, synchronous, and
sleeping. DKMS source 0.1.3 therefore replaces the index-only spinlock with a
mutex held across the complete read or write transaction, including retries,
diagnostics, and the chipset register-section operation. The value of a read is
copied before unlocking. Because serialization leaves at most one transaction
in flight, the rotating 128-entry allocation is reduced to one separately
allocated control word; this retains the original heap-backed USB buffer
requirement without retaining an index that no longer provides concurrency.

## Static validation

- The change has no early return while the mutex is held.
- The nested register-section helper calls USB core directly and does not
  recursively acquire the new mutex.
- Linux v6.12 strict checkpatch reports 0 errors, 0 warnings, and 0 checks for
  the `usb.c`/`usb.h` delta.
- Existing synchronous control-message context already excludes interrupt
  callers; serialization does not turn a valid atomic path into a sleeping one.

## Pending runtime validation

The active eight-hour endurance run intentionally remains on production DKMS
0.1.2. After it completes, build and install 0.1.3 against the exact target
kernel, verify all five loaded source versions, rerun the read-only control
`-EPROTO` injector, strict churn, and unload/reload recovery. Until those gates
pass, 0.1.3 is source-complete but not the validated production package.
