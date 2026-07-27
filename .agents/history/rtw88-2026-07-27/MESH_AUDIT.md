# RTL8812AU 802.11s audit

## Status

The first experimental patch advertises `NL80211_IFTYPE_MESH_POINT` only when
the chip is RTL8812A and the host interface is USB. It does not advertise mesh
for other rtw88 devices and does not add mesh to the multi-interface combination
table, so the initial supported topology is one mesh interface only.

The complete module set builds successfully for ARM64 against Debian 12 kernel
headers 6.1.0-51 (Debian kernel package version 6.1.177-1). This is compile-time
validation, not runtime or RF validation.

## Existing mesh-aware code

- `rtw_ops_add_interface()` accepts mesh point, allocates a beacon reserved
  page, selects AP MAC network mode, and enables beacon functionality.
- Firmware reserved-page construction accepts mesh beacons and obtains them
  from mac80211 with `ieee80211_beacon_get_tim()`.
- mac80211 supplies peer stations individually; the core allocates distinct
  MAC IDs for all non-managed-station peers, matching mesh's multi-peer model.
- RX filtering implements `FIF_OTHER_BSS`, `FIF_BCN_PRBRESP_PROMISC`, multicast,
  control-frame, and FCS flags requested by mac80211.
- Non-station interfaces disable firmware low-power station mode.
- HT rate selection supports two-stream peers through MCS15 when the adapter
  reports 2T2R and the peer advertises a second HT MCS mask.

## Known uncertainty

Upstream commit `7ee700d4a9b7` removed mesh capability advertisement in 2024.
Its commit message says mesh was present during development but was unsupported
and should not work properly. It did not remove the dormant mesh-specific
interface or beacon paths. Runtime testing must therefore establish which of
those paths work rather than assuming the old code is complete.

Items requiring hardware evidence:

1. Mesh interface create/remove without warnings, leaks, or USB faults.
2. Beacon generation, reserved-page download, and autonomous beacon TX.
3. Promiscuous beacon/BSSID filtering needed for discovery and peering.
4. Peer station add/remove, MAC-ID allocation, and firmware media-state reports.
5. Mesh action-frame TX acknowledgements and peer-link state progression.
6. Unicast, multicast, four-address mesh data, and native HWMP forwarding.
7. AMPDU/rate-control operation, including 2SS HT rates.
8. Recovery after peer churn, interface recreation, and module reload.

## First-patch rationale

Only capability advertisement is changed because the callback and firmware code
already contains mesh branches. Adding speculative hardware programming before
capturing the first failure would make root-cause isolation harder. Restricting
advertisement to RTL8812A USB also prevents an untested behavior change across
unrelated PCIe, SDIO, and USB chipsets.

## Mesh broadcast/HWMP finding

On 2026-07-26 a clean two-node test reproduced one-way initial path discovery:
after deleting both neighbor and mesh-path state, an RTL8812AU-originated ping
failed with no path entry, while RTL8192FU-originated traffic immediately
installed paths on both nodes. `tcpdump` on the RTL8192FU endpoint captured no
ARP from the RTL8812AU during the failed case. In the reverse case it captured
the ARP request/reply and subsequent ICMP traffic.

The USB TX selector routed every broadcast/multicast 802.11 frame to
`TX_DESC_QSEL_HIGH`. That queue is intended for AP broadcast/multicast delivery
around DTIM/ATIM; mesh broadcast includes immediately-needed ARP and HWMP
traffic and has no AP DTIM delivery context. `usb.c` now selects the frame's
normal access-category queue for broadcast/multicast on a mesh-point vif while
preserving the high queue for non-mesh interfaces.

Runtime evidence for the candidate fix:

- Five complete leave/join cycles reached `mesh plink: ESTAB` and created an
  RTL8812AU-to-RTL8192FU HWMP path when the RTL8812AU initiated first. All five
  received at least one first-contact reply; four received all three probes and
  one received one of three while discovery completed.
- A capture on the RTL8192FU received all three IPv4 subnet-broadcast packets
  and all three `224.0.0.1` multicast packets originated by RTL8812AU.
- A subsequent 20-cycle leave/join harness passed 20/20 joins, 20/20 peer-link
  establishments, 20/20 cold first contacts in each direction, and 20/20
  multicast deliveries in each direction. Both endpoints had one path after
  every cycle. Typical peer establishment was 116--135 ms; one cycle took
  3.2 seconds.
- A 512 MiB zero stream from RTL8812AU to RTL8192FU completed in 71.894 seconds
  (59.74 Mbit/s). Sender and receiver SHA-256 were both
  `9acca8e8c22201155389f65abbf6bc9723edc7384ead80503839f49dcc56d767`;
  both stations remained `ESTAB` with zero reported TX retries/failures.
- Neither test produced a USB protocol, disconnect, reset, or over-current
  event.
- After adding the shared harness lock and restoring the open mesh from the SAE
  experiment, an uncontended 10-cycle regression passed 10/10 joins, 10/10
  peer links, 10/10 cold first contacts in both directions, and 10/10
  multicast deliveries in both directions. Typical peer establishment was
  117--131 ms, both path tables were populated on every cycle, and the harness
  found no USB error during its 51-second run.
- After narrowing generic USB control retry to reads only, the complete module
  set rebuilt cleanly against the Pi's running `6.12.47+rpt-rpi-v8` kernel. The
  rebuilt stack then passed 20/20 fresh joins, peer links, cold first contacts
  in both directions, and multicast deliveries in both directions. Both path
  tables populated on every cycle, peering took 118--131 ms, and no USB error
  occurred during the 103-second run.
- The later upstream-audited core/USB source built and modposted cleanly in an
  isolated Pi tree against `6.12.47+rpt-rpi-v8`. Loaded module srcversions were
  `B327264D199843173BE3C28` (`rtw_core`) and
  `49718E68E3A0FCEBAC609DB` (`rtw_usb`). A fail-closed, MAC-resolving 10-cycle
  regression passed every join, plink, bidirectional cold contact, multicast
  direction, and pair of HWMP path tables in 52 seconds with no USB event.

This run occurred after module reload switched RTL8812AU from high-speed USB 2
on `1-1.2` to SuperSpeed on `2-2`. It still exposed three bulk-out endpoints,
but the bus/topology changed. The fix therefore remains a candidate until an
A/B test repeats full fresh joins in the original USB 2 mode with
`rtw_usb.switch_usb_mode=N`.

## USB `-EPROTO` finding and recovery

The USB transport had two independent error-handling defects:

- register reads used a rotating buffer without clearing it, then returned its
  contents even when `usb_control_msg()` failed or returned short;
- bulk RX completion treated `-EPROTO`, `-EILSEQ`, `-ETIME`, `-ECOMM`, and
  `-EOVERFLOW` as terminal and did not resubmit that RX URB. Repeated transient
  faults could drain the four-URB receive pool without detaching the device.

The candidate transport fix clears the register-read destination, accepts only
the requested length, retries transient control-read errors up to three
attempts, records per-device retry/error counts in diagnostics, and resubmits
RX URBs after recoverable completion errors. Device removal/cancellation and
endpoint-stall statuses remain terminal rather than being hidden.

An upstream-safety audit found a second RX-pool hole in the resubmit helper. If
`usb_submit_urb()` failed, the skb was returned to the free queue while
`rxcb->rx_skb` could remain non-NULL, preventing the worker from recognizing
the dead slot. The old `-ENOMEM` path could also lose a `queue_work()` request
when called by that same work item. The candidate now clears ownership on every
failed submission and uses `mod_delayed_work()` for allocation and transient
submit failures, with synchronous cancellation during teardown.
Disconnect now cancels that delayed retry before killing active RX URBs, so a
queued retry cannot repopulate an URB while hardware unregister is in progress.

Register writes are deliberately not retried generically: a transfer that
times out at the host may already have reached the device, and repeating a
command or clear-on-write register can have side effects. Failed and short
writes are diagnosed, but safe write retry would require register-specific
semantics and separate evidence.

`tests/usb_eproto_injector.c` is a test-only kprobe module that changes one
otherwise-successful `rtw_usb_read_port_complete()` status to `-EPROTO`. One
injection caused the expected one-packet loss, logged recovery, preserved the
established peer, and was followed by 20/20 successful pings. Eight further
one-shot injections (twice the RX pool size) all logged resubmission; concurrent
traffic received 294/300 probes, the peer remained established, and a post-test
20-packet run had zero loss. Without resubmission, four injected completions
would retire the entire RX pool.

After the delayed-resubmit audit change, another eight-injection run delivered
297/300 concurrent probes, followed by 20/20 in both directions, mutual
`ESTAB`, and zero RTL8812AU TX retries/failures. This exercises completion-error
recovery; a deterministic `usb_submit_urb()` failure injector is still needed
to directly exercise the newly corrected submission-failure branch.

`tests/usb_ctrl_eproto_injector.c` targets one RTL8812AU vendor control message
for a selected register and changes its successful return to `-EPROTO`. A
debugfs read of register `0x5a7` consumed the fault and the injector observed
exactly two matching calls with zero missed probes: the injected first attempt
and the driver's successful retry. The caller received the expected register
value and no final register error, USB reset, or disconnect was logged.

This proves recovery from transient RX `-EPROTO`. It does not make a physical
over-current disconnect recoverable inside the kernel driver; re-enumeration
destroys the netdev and requires a userspace mesh reconstruction service.

## Netdev reconstruction after USB return

The Pi test recovery service is represented by `tests/pi_mesh_recover.sh`,
`tests/rtw88-mesh-recover.service`, and
`tests/99-rtw88-mesh-recover.rules`. It identifies radios by fixed MAC rather
than unstable `wlanN` names, keeps NetworkManager away from the test devices,
moves RTL8192FU back into `meshpeer` when necessary, restores mesh type/channel
and addressing, and waits for both peer links to become established. Recovery
and test harnesses serialize on `/run/lock/rtw88-mesh-test.lock`; the service
waits for a bounded 90 seconds rather than racing an active reload or churn run.

Two end-to-end recovery tests passed:

- Reloading the complete RTL8812AU module stack caused a USB reset and a fresh
  netdev. The udev-triggered service restored both peer links in about two
  seconds and subsequent traffic passed 10/10.
- Unbinding both `rtw_8812au` and `rtl8xxxu`, then rebinding them, removed both
  netdevs and returned RTL8192FU to the root namespace. The service moved it
  back into `meshpeer`, handled RTL8812AU returning under a different name,
  reached `ESTAB` on both sides about three seconds after bind, and passed
  forward 10/10 plus steady-state reverse 20/20 traffic. The first immediate
  reverse run was 9/10 while HWMP warmed.

This validates reconstruction after driver unbind/rebind and USB reset. A real
over-current removal/re-enumeration still needs an endurance run to confirm the
same udev path under physical bus failure.

RTL8812AU now enumerates at SuperSpeed on direct root port `2-2`, while
RTL8192FU remains at high speed behind VIA hub port `1-1.4`. No `-71`, reset,
disconnect, or current undervoltage flag occurred during the first direct-path
mesh and churn runs. The original overnight failure remains classified as an
external event because repeated over-current notifications affected the root
ports and both hub-attached radios disconnected/re-enumerated together.

The current direct-port arrangement separates the devices across logical USB
buses but not across independent power supplies. It is useful for protocol and
recovery testing, but cannot replace the pending powered-root-path endurance
test needed to isolate load-dependent power faults.

Several packet captures were invalidated by a second SSH workflow explicitly
running `rmmod`/`insmod` during the test. The journal distinguishes these from
driver recovery by recording the sudo commands immediately before interface
driver deregistration, with no `-EPROTO` or physical disconnect. The reusable
churn harness takes `/run/lock/rtw88-mesh-test.lock` to prevent two harness
instances from overlapping; manual reload workflows must use the same lock.
The recovery-aware soak harness also owns this lock while the mesh exists and
aborts if test SAE supplicants are attached. If USB removal makes either radio
unavailable, it briefly yields the lock so the udev recovery service can
reconstruct the topology, then reacquires exclusive test ownership.

A 75-second harness qualification run passed four established-state checks,
80/80 ping replies across eight directional batches, and four checksummed 1 MiB
transfers. Both HWMP tables populated after cold traffic. An eight-hour managed
run then started on the direct-port topology. This run can exercise protocol,
driver, thermal, and automatic-recovery behavior, but it cannot isolate the
shared Pi USB power budget in the way the pending independently powered-path
test can.

One later run captured an externally initiated RTL8192FU reset. The sudo journal
showed `bash -s` at the exact timestamp; there was no `-71`, over-current, or
spontaneous disconnect. The soak detected the missing namespace peer, yielded
its shared lock, and udev recovery restored the open mesh about three seconds
after lock release. Failed transfers are now retried after recovery rather than
deferred for a full interval. This validates deliberate peer-reset recovery but
is excluded from uncontended endurance evidence.

A fresh strict-preflight run was independently invalidated after 2 minutes 34
seconds by another `sudo bash -s` workflow resetting RTL8812AU and injecting
eight RX `-EPROTO` completions despite the harness lock. Before that mutation,
three state samples, six directional ping batches, and both initial checksummed
10 MiB transfers passed. Every injected completion logged RX URB resubmission.
This is additional fault-recovery evidence, not endurance evidence; long runs
must wait until all hardware workflows honor the common lock.

After all competing workflows released the lock, a clean thermal-aware
15-minute direct-port run completed on the latest build. All 27 state samples
showed mutual `ESTAB` with one HWMP path on each endpoint. All 54 ten-probe
directional batches passed (270 probes each direction), and all 14 checksummed
64 MiB transfers passed (448 MiB each direction). There were no recovery
windows, invalidations, transport events, USB resets, `-71`, over-current, or
disconnect records. Temperature stayed between 78.880 C and 81.315 C and the
current throttle mask remained clear (`get_throttled=0xe0000`; historical bits
remain latched). This is bounded current-topology endurance evidence only:
RTL8812AU was SuperSpeed on root bus `2-2`, RTL8192FU was high-speed behind
`1-1.4`, and neither adapter had an independently powered path.

## Secured mesh status

A two-supplicant SAE/AMPE test used Debian `wpa_supplicant` 2.10 and a
test-only CCMP profile. It did not reach secured peering, but the evidence does
not yet identify an RTL8812AU security failure:

- RTL8192FU received RTL8812AU's secured mesh beacon and emitted
  `NL80211_CMD_NEW_PEER_CANDIDATE` for it.
- RTL8192FU transmitted SAE commits; TX status reported ACK, and RTL8812AU
  delivered those authentication frames to its supplicant.
- RTL8812AU correctly rejected the commits because it had never received a
  peer-candidate notification for RTL8192FU.
- The RTL8192FU supplicant logged `Beacon set failed: -95 (Operation not
  supported)` while trying to update its mesh beacon after candidate/HT state
  changed. Thus the experimental reference driver did not provide a valid
  secured beacon path back to RTL8812AU.

Follow-up debugging found and fixed two RTL8812AU receive/key-admission
requirements. Mesh filtering must honor `FIF_OTHER_BSS` as well as
`FIF_BCN_PRBRESP_PROMISC`; otherwise the hardware leaves beacon BSSID filtering
enabled and wpa_supplicant drops directed SAE authentication from a peer it has
not discovered. The 8812 USB mesh wiphy also needs `WIPHY_FLAG_IBSS_RSN` so
cfg80211 accepts per-peer MGTK/IGTK installs. With those changes, a cold run
reached SAE `Accepted` and mutual `ESTAB`, authenticated, authorized, MFP peers;
RTL8812AU negotiated MCS 15 and accepted pairwise, MGTK, and IGTK operations.

Protected traffic still failed. Static neighbor entries proved the failure was
not only encrypted ARP. The candidate now returns `-EOPNOTSUPP` for every mesh
key so mac80211 performs software crypto instead of using the legacy rtw88 CAM
path, which does not model mesh per-peer key selection. That build succeeds,
but its cold end-to-end test was blocked before SAE by the RTL8192FU driver's
recurring `rtl8xxxu_send_beacon_frame: Failed to read beacon valid bit` error.
The Pi 4 onboard `brcmfmac` PHY advertises managed/AP/P2P modes but not mesh
point, so a known-good secured reference is still required to validate protected
unicast/multicast traffic and the software-crypto fallback.

A later concurrent SAE attempt left both netdevs showing MFP and `ESTAB` after
the supplicants exited, but both mesh link IDs were zero and protected traffic
failed 20/20 plus 5/5 probes. The RTL8192FU log recorded
`MESH-SAE-AUTH-FAILURE`, `NL80211_CMD_SET_STATION` returning `-EINVAL`, and the
same secured beacon update returning `-EOPNOTSUPP`. This is stale teardown state,
not successful security evidence, and reinforces that the experimental peer is
still the blocking component.

The secured-test cleanup now terminates both supplicants, leaves the secured
mesh, releases the common test lock, and invokes open-mesh reconstruction. If
the known RTL8192FU beacon-valid failure prevents rejoining, it rebinds only the
experimental peer driver and retries reconstruction. This prevents a failed
security experiment from contaminating later open-mesh evidence.

Linux 6.12 source review clarified the security flags. Despite its legacy name,
cfg80211 checks `WIPHY_FLAG_IBSS_RSN` before admitting any non-pairwise key with
a peer MAC, including mesh MGTK/IGTK, so RTL8812AU mesh must advertise it for
those nl80211 operations to reach the driver. In contrast,
`IEEE80211_HW_SUPPORTS_PER_STA_GTK` is deliberately not set: `key.c` uses its
absence to keep per-peer group keys in mac80211 software. The all-software mesh
key fallback remains a candidate that cannot be validated with the current
broken secured peer. The legacy flag also exposes IBSS-RSN capability metadata,
an API coupling that must be called out in any upstream submission.

The RTL8812AU USB wiphy exposes mesh through `interface_modes` but deliberately
omits it from the existing station/AP concurrency combination. An intermediate
attempt to add a one-interface mesh combination was rejected at registration by
`wiphy_verify_iface_combinations()` because combinations with fewer than two
interfaces are invalid (except DFS). Removing that redundant record restored
registration: `iw phy` shows mesh point support while its only valid concurrent
combination still excludes mesh. A runtime attempt to add a managed interface
beside the active mesh was rejected with `-EPERM`; the existing mesh peer stayed
`ESTAB`.
