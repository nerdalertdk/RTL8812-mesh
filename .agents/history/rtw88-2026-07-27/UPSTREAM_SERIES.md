# Proposed upstream series

Do not submit the working-tree diff as one patch. Keep mesh enablement and
generic USB reliability reviewable and bisectable in this order.

## 1. wifi: rtw88: usb: validate register control-transfer lengths

- Zero read destinations before every attempt.
- Accept only the requested transfer length.
- Never run the protected-register follow-up after a failed/short transfer.
- Diagnose failed/short writes without retrying potentially non-idempotent
  register writes.
- Fix the CAM upper-bound check separately if maintainers prefer it outside
  this series; it is unrelated to mesh and USB transport.

Evidence: exact `6.12.47+rpt-rpi-v8` build; targeted register `0x5a7` kretprobe
changed the first successful transfer to `-EPROTO`, observed two matching calls
and zero misses, and the driver logged recovery after two attempts.

## 2. wifi: rtw88: usb: retry transient register reads

- Bound retry to three attempts.
- Retry only transport statuses that are safe for reads.
- Rate-limit terminal and successful-recovery diagnostics.
- Do not retry writes generically.

Keep this separate from patch 1 if reviewers want validation/error reporting
without retry policy in the first change.

## 3. wifi: rtw88: usb: preserve RX URBs after transient errors

- Resubmit after recoverable completion statuses.
- Clear `rxcb->rx_skb` after failed submission before returning the skb.
- Use delayed work for allocation/transient submit failures so a worker cannot
  lose a self-requeue.
- Cancel delayed retry before killing URBs and before destroying the workqueue.

Evidence: eight injected completion `-EPROTO` events (twice the four-URB pool)
delivered 297/300 concurrent probes, followed by 20/20 in both directions,
mutual `ESTAB`, and zero RTL8812AU TX retries/failures. Direct deterministic
`usb_submit_urb()` failure injection remains unavailable because the Pi kernel
has `CONFIG_FAULT_INJECTION` disabled; do not claim that branch as runtime
validated.

## 4. wifi: rtw88: honor FIF_OTHER_BSS in receive filtering

- Clear beacon/data BSSID checks while either `FIF_OTHER_BSS` or
  `FIF_BCN_PRBRESP_PROMISC` is requested.

Evidence: before the change mac80211 requested `FIF_OTHER_BSS` but RTL8812AU
kept `BIT_CBSSID_BCN`; clearing it made peer discovery and SAE proceed. A cold
rebuild reproduced mutual SAE Accepted/authenticated/authorized/MFP `ESTAB`
without a live register override.

This is generic rtw88 behavior and should be submitted independently of
RTL8812AU mesh advertisement.

## 5. wifi: rtw88: usb: use an access-category queue for mesh multicast

- Preserve the AP high/DTIM queue behavior.
- Route mesh broadcast/multicast through its normal access category.

Evidence: before the change RTL8812AU-originated ARP/HWMP/multicast did not
reach the peer; afterward repeated cold joins, HWMP paths, broadcast and IPv4
multicast passed, including a 20-cycle churn run and checksummed 512 MiB stream.
USB2 fresh-join A/B is still required before submission.

## 6. wifi: rtw88: enable standalone mesh point on RTL8812AU USB

- Add mesh only for `RTW_CHIP_TYPE_8812A` over USB.
- Keep mesh absent from the existing concurrency combinations; standalone
  operation is represented by `interface_modes`.
- Advertise `WIPHY_FLAG_IBSS_RSN`, required by cfg80211 for per-peer mesh group
  keys, but not `SUPPORTS_PER_STA_GTK`.
- Return `-EOPNOTSUPP` for mesh keys so mac80211 performs pairwise, MGTK and
  IGTK crypto instead of the legacy CAM.

Evidence: open mesh behavior is strong; SAE reaches mutual protected `ESTAB`.
Protected payload traffic with software crypto is not yet validated because the
experimental RTL8192FU peer repeatedly fails beacon/key handling. Do not submit
this final enablement patch until a second stable RTL8812AU or other unmodified
known-good peer passes secured unicast, ARP, multicast and MFP tests.

## Quality gates

- Exact target-kernel build and `git diff --check`.
- Linux `checkpatch.pl --strict`: tracked diff currently passes with zero
  errors, warnings or checks.
- The RX injector passes checkpatch. The control injector's only checks are
  unavoidable references to kernel USB descriptor members `idVendor` and
  `idProduct`.
- Open cold join/HWMP/broadcast/multicast/churn and 512 MiB hash verification.
- Secured two-RTL8812AU traffic and rekey/churn.
- Original USB2 topology A/B, physical unplug/re-enumeration recovery, and an
  independently powered-path comparison before production stability claims.
