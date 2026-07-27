# SESSION.md

## Current Focus

Make RTL8812AU native 802.11s behavior robust and diagnose, prevent, or recover
from USB `-EPROTO` (`-71`) without conflating driver faults with the confirmed
shared-hub over-current event.

## Current Status

- Adapter detected as Realtek `0bda:8812`, serial `123456`.
- Device enumerates at USB 2.0 high speed (480 Mbit/s).
- Development host is arm64 macOS 26.5 (Darwin 25.5.0).
- Docker Desktop exists, but containers do not provide a Linux kernel module
  test environment or normal direct USB passthrough on macOS.
- Driver source already contains RTL8812AU support but does not advertise mesh.
- Debian is the first target; Android integration follows validated Debian mesh
  operation.
- Initial RF scope is 2.4 GHz HT20 on one permitted fixed channel.
- The driver supports RTL8812AU 2T2R/2SS HT operation, but certain adapters can
  report an efuse-limited 1T1R configuration that must be checked on hardware.
- The end goal is a self-operated MANET. The RTL8812AU mesh-point interface is
  the bearer, but MANET overlays and downstream platform integration are outside
  the current milestone.
- An experimental patch now advertises mesh point only for RTL8812A USB. It does
  not advertise mesh concurrency or enable mesh for other rtw88 devices.
- The full module set compiles against Debian 12 ARM64 6.1.177 headers and the
  Pi's exact `6.12.47+rpt-rpi-v8` headers.
- The Raspberry Pi 4 runs Debian 13.1 arm64 and uses Ethernet for test-safe SSH.
- The live adapter reports 2T2R/2SS, antennas `0x3`, and HT MCS 0-15.
- The local modules probe successfully and advertise mesh only on the RTL8812AU
  PHY. Ten create/up/down/delete lifecycle cycles completed without rtw88 errors.
- With NetworkManager paused, an open `rtw88-test` mesh joins on channel 1 HT20,
  remains type `mesh point`, reports forwarding enabled, and transmits packets.
- A second USB device initially believed to be RTL8812EU is actually RTL8192FU
  (`0bda:f192`), 2T2R, using `rtl8xxxu`.
- A matching-kernel, RTL8192F-only `rtl8xxxu` experiment enabled mesh by sharing
  its AP link type, beacon setup, receive filter, and peer MAC-ID paths.
- `mesh8812` and namespace-isolated `mesh8192` established an open peer link on
  channel 1 HT20. Both reported `mesh plink: ESTAB`, MCS15 rates, and bidirectional
  `10.44.0.1/24` to `10.44.0.2/24` traffic.
- Two 100-packet directional ping runs passed with zero loss. Network namespaces
  ensure these packets traversed the RF link rather than the local route table.
- A 512 MiB HTTP transfer from RTL8192FU to RTL8812AU completed in 53.57 seconds
  at 10.02 MB/s (about 80.2 Mbit/s application throughput). Source and received
  SHA-256 hashes matched, and both drivers reported zero TX failures.
- Transient systemd service `mesh-overnight-soak.service` now runs continuous
  timestamped ping in both directions, records mesh plink/carrier state every
  60 seconds, and transfers/checksums 10 MiB each way every 3600 seconds.
- The soak's first transfer pair passed in both directions. Logs live under
  `/home/msh/mesh-soak/`, with `latest.log` pointing at the current run.
- `mesh-soak-finish.timer` will stop the run after about eight hours and produce
  `latest-summary.log` with sequence-gap, state, transfer, peer, power, and
  filtered kernel-log evidence.
- The soak was stopped on request after about 7 hours 23 minutes. It stayed
  healthy for roughly 2 hours 55 minutes, then both USB radios disconnected and
  re-enumerated. Mesh interfaces were not recreated, so there was no recovery.
- Three hourly 10 MiB transfer pairs passed with matching hashes before the USB
  event. Five later pairs failed because `mesh8812` and `mesh8192` no longer
  existed. The summary contains 176 healthy and 269 connection-lost checks.
- Kernel evidence shows RTL8812AU USB protocol errors (`-71`) immediately before
  both hub-attached adapters disconnected. This makes USB power, hub, cable, or
  host-controller behavior the leading cause; it is not evidence of an isolated
  802.11s peer-link failure.
- NetworkManager is active again. A reboot-ephemeral rule under `/run` keeps
  `mesh8812` unmanaged while the live experiment remains up.
- Clean state testing isolated the delayed HWMP symptom to missing outbound
  RTL8812AU mesh broadcast: the RTL8192FU captured no ARP and neither endpoint
  created a path until traffic was initiated in the reverse direction.
- The rtw88 USB selector sent all broadcast/multicast through the AP-oriented
  high queue. A candidate fix sends mesh-point broadcast/multicast through its
  regular access-category queue while leaving AP behavior unchanged.
- With the candidate fix loaded, five complete mesh leave/join cycles all
  established an RTL8812AU-initiated path. Peer capture received 3/3 subnet
  broadcasts and 3/3 IPv4 multicast probes from RTL8812AU.
- A hardened 20-cycle churn run then passed all joins, peer links, bidirectional
  cold first contacts, and bidirectional multicast delivery. Every cycle built
  paths on both endpoints; no USB error occurred during the run.
- A later uncontended, lock-protected 10-cycle regression again passed every
  join, peer link, cold HWMP contact, and multicast direction with paths on
  both endpoints and no USB error.
- The read-only-retry cleanup rebuilt without warnings on the exact Pi kernel
  and passed a further 20-cycle regression: every join, peer link, bidirectional
  cold HWMP contact, and multicast direction passed, with paths on both sides
  and no USB errors.
- The current audited core/USB source also built cleanly in an isolated Pi tree,
  loaded with srcversions `B327264D199843173BE3C28` and
  `49718E68E3A0FCEBAC609DB`, and passed a corrected 10-cycle churn regression
  across every join, link, cold HWMP, multicast, and path-table gate.
- `tests/pi_mesh_churn.sh` now resolves both namespace interfaces by permanent
  MAC and exits nonzero unless every required gate passes; the prior hard-coded
  peer name could print a zero-pass summary while returning success.
- A patched RTL8812AU-to-RTL8192FU 512 MiB stream passed with matching SHA-256
  at 59.74 Mbit/s, an established peer link, and zero TX retries/failures.
- USB register reads previously returned stale rotating-buffer data after a
  failed transfer, and recoverable bulk-RX errors silently retired URBs. The
  candidate fix clears/validates reads, retries transient control faults, and
  resubmits RX URBs after recoverable completion errors.
- A test-only kprobe injected nine total RX `-EPROTO` completions. All logged
  resubmission; eight consecutive injections exceeded the four-URB pool size
  without stopping receive. The peer remained established and post-test ping
  passed 20/20.
- A targeted kretprobe injected `-EPROTO` into one register `0x5a7` control
  read. It observed exactly two matching calls with no misses, proving the
  bounded retry executed and succeeded without a reset or disconnect.
- The refined diagnostic build repeated that test through debugfs byte-register
  access: the driver logged `read register 0x5a7 recovered after 2 attempts,
  retries=1`; the injector again reported `matching_calls=2 missed=0`.
- Repeated module reloads expose delayed udev renames between `wlan1` and
  `wlan2`. Test and recovery tooling must resolve RTL8812AU by its fixed MAC or
  USB identity instead of persisting an interface name.
- A udev/systemd recovery service now reconstructs mesh state by radio MAC.
  RTL8812AU-only module reload restored `ESTAB` automatically in about two
  seconds. Simultaneous rtw88/rtl8xxxu unbind/rebind also restored namespaces,
  mesh state, paths, and bidirectional traffic automatically.
- Reloading without `rtw_usb.switch_usb_mode=N` moved RTL8812AU from USB 2
  `1-1.2` to SuperSpeed `2-2`. It remains a three-bulk-out device and is now on
  a separate root bus from RTL8192FU, but USB2 A/B validation still requires a
  physical replug and reload with mode switching disabled.
- USB transport hardening under test retries transient control reads three
  times, never returns stale register-buffer contents after a failed read, and
  resubmits recoverable failed RX URBs instead of permanently draining the
  four-URB receive pool.
- RX resubmission now also clears stale skb ownership after a failed
  `usb_submit_urb()` and uses guaranteed delayed retry rather than self-queuing
  ordinary work. The exact Pi build passed eight injected completion `-EPROTO`
  events with 297/300 concurrent and 20/20 post-test traffic in both directions.
- Disconnect synchronously cancels delayed RX submission retries before killing
  active URBs, closing a retry-versus-unregister race found during code review.
- Security capability review retains `WIPHY_FLAG_IBSS_RSN`, required by Linux
  6.12 cfg80211 for per-peer non-pairwise mesh keys, but does not advertise
  `SUPPORTS_PER_STA_GTK` because RTL8812AU mesh keys deliberately use software
  rather than hardware per-station crypto.
- The complete tracked diff passes the exact Linux 6.12 `checkpatch.pl
  --strict` with zero errors, warnings, or checks. The proposed six-patch
  submission structure and remaining evidence gates are in
  `.agents/UPSTREAM_SERIES.md`.
- A post-injection 20-probe reverse run briefly delivered 16/20, but immediate
  longer repetition passed 50/50 in both directions with mutual `ESTAB` and
  zero RTL8812AU retries/failures. No spontaneous `-71` accompanied it. The Pi
  was 81.3 C with historical throttling flags, so thermal state remains a
  controlled variable for endurance claims.
- `tests/pi_mesh_churn.sh` now takes a run lock so duplicate harness instances
  fail rather than silently invalidating each other's evidence.
- The canonical recovery helper uses that same run lock with a bounded 90-second
  wait, preventing udev recovery from racing an intentional reload or churn run.
- Two stale test-only SAE supplicants were found attached during one controlled
  reload; after terminating those exact PID-file-scoped processes, the rebuilt
  open mesh reached `ESTAB` and passed 10/10 pings in both directions.
- An initial soak-harness functional run was invalidated when another workflow
  reloaded RTL8812AU and started SAE supplicants during the run; MFP became
  active with zero mesh link IDs and traffic stopped. The soak now owns the
  shared test lock and rejects attached test supplicants instead of recording
  concurrent manipulation as a driver failure.
- The corrected recovery-aware soak passed a 75-second functional run with four
  established-state samples, 80/80 ping replies across eight directional
  batches, and four checksummed 1 MiB transfers. It resolved renamed interfaces
  by MAC and observed HWMP paths populate after cold traffic.
- Managed service `rtw88-mesh-soak.service` began an eight-hour direct-port run
  at 2026-07-26 13:30 CEST, but its first cycle was invalidated by residual
  secured-mesh state and the service was stopped. The harness now requires the
  expected addresses, MFP disabled, and bidirectional cold contact before it can
  start; it terminates if those open-topology invariants change mid-run.
- A deliberate external `sudo bash -s` reset RTL8192FU during a subsequent run.
  The journal contained no `-71` or over-current event. The soak detected the
  missing peer and yielded its lock; udev recovery restored the peer about three
  seconds after lock release and traffic resumed. This is valid reconstruction
  evidence but invalidates that interval as uncontended endurance.
- The corrected eight-hour run started at 2026-07-26 13:39 CEST. Strict
  preflight passed, the first two 10-packet directional batches passed, and the
  first checksummed 10 MiB transfers passed at about 8.19 MB/s root-to-peer and
  4.79 MB/s peer-to-root. The service holds the shared test lock.
- That run self-invalidated after 2 minutes 34 seconds when an external
  `sudo bash -s` workflow reset RTL8812AU despite the shared lock, then injected
  eight synthetic RX `-EPROTO` completions. Before mutation it passed three
  established-state samples, six complete directional ping batches, and both
  checksummed transfers. All eight injected RX faults logged resubmission.
  Uncontended endurance is paused until the competing hardware workflow is idle.
- Pi `get_throttled=0xe0008` coincided with 81.3 C and returned to `0xe0000`;
  the active low bit was soft-temperature limiting, not undervoltage. The Pi
  remained near 82 C before the long soak, so thermal state is a separate test
  variable and will be retained in the result.
- The soak harness now samples temperature/throttle state every poll and
  self-invalidates at 85 C. A clean 15-minute direct-port run on the latest
  build passed 27/27 established states, 54/54 ten-probe directional batches,
  and 14/14 checksummed 64 MiB transfers (448 MiB each direction). It recorded
  zero recovery windows, invalidations, resets, `-71`, over-current, or
  disconnect events; temperature ranged from 78.880 C to 81.315 C with no
  active throttle bit. This does not substitute for USB2/powered-path testing.
- A temporary SAE/AMPE run proved RTL8812AU receives peer SAE authentication
  frames, but the experimental RTL8192FU reference failed its secured beacon
  update with `-EOPNOTSUPP`. RTL8812AU therefore never received a peer-candidate
  notification and correctly dropped the unsolicited commits. Security remains
  unvalidated rather than failed on RTL8812AU.
- The secured harness now resolves and normalizes both radios by permanent MAC,
  so post-recovery `wlanN` renames cannot invalidate crypto testing.
- RTL8812AU secured peering now reaches SAE `Accepted` and mutual authenticated,
  authorized, MFP `ESTAB` after fixing mesh beacon filtering and advertising
  per-peer RSN key admission. RTL8812AU accepted pairwise, MGTK, and IGTK key
  operations; only the experimental RTL8192FU peer logged group-key validation
  failures in that run.
- Protected unicast also failed with static neighbors, so all RTL8812AU mesh
  keys now deliberately fall back to mac80211 software crypto rather than the
  legacy CAM. The exact Pi build loads, but validation is blocked by recurring
  RTL8192FU beacon-valid failures before SAE; this is not accompanied by a new
  RTL8812AU `-71`.
- `.agents/MESH_AUDIT.md` records findings and `.agents/PI_MESH_TEST.md` contains
  the initial hardware test and rollback procedure.

## Known Issues

- No unmodified known-good 802.11s reference peer has been inventoried yet; both
  sides of the successful test use experimental capability patches.
- Endurance, secured mesh, and unmodified-peer interoperability remain
  unvalidated. Basic RTL8812AU-originated broadcast and IPv4 multicast delivery
  pass with the candidate queue fix, but need USB2 A/B repetition.
- After a unilateral peer leave/rejoin, plinks returned to `ESTAB` before traffic
  recovered. Bidirectional traffic resumed after the reverse direction populated
  neighbor/HWMP state; this churn behavior needs focused testing.
- NetworkManager races with manual `iw` setup and converts a newly created
  `mesh0` to managed mode unless it is stopped or configured to ignore it.
- A simultaneous USB disconnect destroys both mesh interfaces. The installed
  MAC-address-driven recovery service reconstructs namespaces, interface types,
  addressing, and peer state after driver rebind or USB reset. Recovery from a
  real over-current removal/re-enumeration still needs endurance validation.
- Transient RX `-EPROTO`, control-read retry, and driver unbind/rebind
  reconstruction are injection/end-to-end tested. Physical over-current replug
  recovery remains unvalidated.
- `.agents/` is ignored by the repository's broad `.*` gitignore rule.
- Manual module reloads from another SSH workflow can still invalidate a test;
  traffic and reload scripts need to honor the same mesh-test lock.
- The available RTL8192FU experiment cannot yet update its secured mesh beacon,
  and now intermittently fails its beacon-valid poll entirely. The Pi onboard
  brcmfmac PHY does not advertise mesh point. A known-good secured reference
  peer is still required to validate protected traffic.

## Next Steps

1. Extend the clean bounded direct-port endurance result to a long unattended
   run while retaining thermal and transport diagnostics.
2. Add a safe deterministic test for the transient `usb_submit_urb()` failure
   branch when a kernel with function fault injection is available.
3. When physical access permits, repeat patched/unpatched fresh-join A/B on the
   original USB 2 mode and validate real unplug/re-enumeration recovery timing.
4. Select an unmodified known-good 802.11s peer for interoperability, secured
   mesh, and independent HWMP validation.
5. Repeat endurance with independently powered USB paths before making a
   production-stability claim.
