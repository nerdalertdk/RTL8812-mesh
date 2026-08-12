# Mesh teardown warning and incomplete-peer incident

## Scope and status

This is an invalidated transition interval, not runtime qualification of DKMS
0.1.6.  The clean DKMS 0.1.5 bounded soak completed before this incident.
DKMS 0.1.6 was subsequently built with `W=1` and registered/installed, but it
had **not** been loaded when the warning below was observed.

## Observed facts

At `2026-08-12 14:08:38` local Pi time, a controlled attempt to leave mesh and
take the RTL8812AU interface down produced:

```
WARNING: CPU: 1 PID: 2902 at net/mac80211/iface.c:519 ieee80211_do_stop
Call trace:
  ieee80211_do_stop
  ieee80211_stop
  __dev_close_many
  __dev_change_flags
  do_setlink
```

The kernel was running the old loaded 0.1.5 source versions at that point.
There was no USB transport (`-71`) event in the warning context.

Afterward, both USB interfaces remained bound to `rtw_8812au` at `1-1.1:1.0`
and `1-1.4:1.0`, but only the `fc:22:1c:30:08:c1` adapter on `1-1.4` had a
registered PHY/netdev (`wlan2`).  `fc:22:1c:30:0d:8b` on `1-1.1` had no
registered PHY/netdev in either root or `meshpeer` namespace.

## Required follow-up

Do not use this interval as 0.1.6 evidence.  First determine the mac80211
teardown invariant behind the warning, recover the missing peer through a
controlled USB-driver rebind or a corrected teardown procedure, then repeat
provenance and mesh qualification with a clean kernel interval.
