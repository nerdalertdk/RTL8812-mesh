# Session

## Current focus

Validate the final DKMS 0.1.1 package and close the remaining hardware gates
that require a second stable RTL8812AU or independently powered USB paths.

The deployment requirement is now also recorded: multinational, off-grid
mobile MANET operation with an approximate 1 km LOS target at 2.4 GHz HT20.

## Current status

- Source imported from a local `rtw88` development worktree at base commit
  `a56bcd2`, including the current uncommitted mesh/USB fixes.
- The focused build produced exactly five modules against Pi kernel
  `6.12.47+rpt-rpi-v8`.
- DKMS package `rtl8812au-mesh/0.1.0` is installed; all five loaded module
  source versions match their artifacts in `updates/dkms`.
- The packaged driver passed the 2026-07-26 one-cycle open-mesh churn smoke:
  plink, bidirectional first contact, multicast, and HWMP paths all passed,
  with no USB errors reported since test start.
- A 2026-07-26 channels 1--13 HT20 sweep passed link, bidirectional unicast,
  and HWMP on every channel. It finished 12/13 because one peer-to-root
  multicast burst was not observed on channel 2; an alternating channel 1/2
  control then passed 10/10. No USB transport events occurred. The channel
  gate remains open until the intermittent multicast result is explained or
  repeated with two RTL8812AU radios.
- A 600-second channel-1 endurance run completed with 17/17 established state
  samples, 34/34 successful 10-packet ping batches, and 18/18 checksummed
  32 MiB transfers (576 MiB total). It recorded zero unavailable states,
  recovery windows, invalidations, transfer failures, or USB transport events.
  Pi temperature ranged from 78.880 to 80.828 C; `get_throttled=0xe0000`
  records historical under-voltage/throttling flags but no current low-bit
  throttle condition during the run.
- Synthetic RX submit fault injection consumed eight `-EPROTO` failures and
  restored all four RX slots (`success_mask=0xf`) with 40/40 pings in both
  directions. A post-fault run passed six checksummed 32 MiB transfers.
- Teardown with 99,981 synthetic failures still pending removed all five
  modules in 593 ms without a kernel warning/Oops/UAF signature. The production
  DKMS stack was restored, source-version verified, and the mesh re-established.
  Detailed evidence is in `tests/results/2026-07-26-rx-submit-eproto.md`.
- `rtw88-mesh-soak.service` started an eight-hour run at 2026-07-26 15:29:33
  CEST (run ID `20260726T132933Z`, expected completion 23:29 CEST). Its
  preflight, first established/HWMP state, first two ping batches, and first
  bidirectional checksummed transfers passed with no kernel transport event.
  Logs are under the soak harness's configured `LOG_DIR` on the Pi.
- A serialized `tests/pi_mesh_multicast_probe.sh` diagnostic is ready for the
  next free hardware window. It counts each burst simultaneously at sender and
  receiver to improve on the sweep's binary multicast capture result.
- Driver review found that mesh capability advertisement was not conditional
  on `CONFIG_MAC80211_MESH`. `main.c` now uses `IS_ENABLED()` so kernels built
  without mac80211 mesh support cannot be offered a nonfunctional mesh mode.
  Exact-kernel rebuild is deferred until the active soak completes to avoid
  adding CPU heat to the endurance evidence.
- Safety review found the control `-EPROTO` kretprobe could match both reads and
  writes because both use request `0x05`. It now additionally requires request
  type `0xc0`, so it can alter only successful RTL8812AU vendor-device reads.
- `tests/USB_PATH_MATRIX.md` now defines the controlled physical test rows,
  repetitions, evidence capture, event classification, and causal decision
  rules required to separate driver/adapter faults from Pi USB power/topology.
- `tests/pi_mesh_transfer.sh` now provides the matrix's standalone
  bidirectional 512 MiB SHA-256 integrity gate and is queued behind the active
  soak's shared hardware lock.
- Repository DKMS version is now `0.1.1`, separating post-baseline source from
  the `0.1.0` modules used by the active endurance run. Version `0.1.1` has not
  yet been built or installed on the Pi.
- Packaging review documented the shared `rtw_core`/`rtw_usb` ABI constraint
  and added a loaded-module preflight check for unrelated `rtw_*` consumers.
- The production soak was stopped on request at 20:00 CEST after about 4.5
  hours. It passed 337/337 established states, 672/672 directional ping
  batches, and 10/10 checksummed transfers with zero recovery windows,
  invalidations, or kernel USB transport events. Temperature was
  75.958--80.828 C.
- DKMS 0.1.1 built cleanly against `6.12.47+rpt-rpi-v8`, installed all five
  modules, and loaded with source versions matching the build artifacts.
  Automatic recovery restored the open mesh in five seconds; immediate
  bidirectional traffic passed 10/10 each way without a kernel warning.
- The post-install multicast capture probe observed all 400 frames at each
  sender. The opposite endpoint received 399/400 RTL8812AU-originated frames
  and 398/400 RTL8192FU-originated frames. No USB event occurred. This
  localizes the small loss after sender capture but does not attribute it to
  one driver; 802.11 multicast is unacknowledged and the peer is experimental.
- The DKMS 0.1.1 channels 1--13 HT20 sweep passed peer establishment,
  bidirectional cold unicast, and both HWMP path tables on every channel. One
  three-frame peer-originated multicast gate missed again on channel 2, while
  all other gates passed. Ten subsequent fresh channel-2 joins passed every
  gate 10/10 with no USB error, excluding a consistently broken channel-2 path.
- The final-build bidirectional 512 MiB gate passed matching SHA-256 in both
  directions at 8.77 MB/s RTL8812AU-to-peer and 6.34 MB/s peer-to-RTL8812AU,
  retaining both HWMP paths with no USB transport event.
- The transfer harness initially exposed an HTTP readiness race and a
  namespace server inheriting the shared lock. It now probes both endpoints
  before measurement, closes the lock FD in children, terminates wrapper
  children, and waits for cleanup. A 1 MiB smoke passed both directions with
  no orphan server and the lock free afterward.
- The read-only control injector initially reported zero matches on ARM64
  because full register-sized values were compared for narrow USB API
  arguments. Casting request/request-type/value to `u8`/`u8`/`u16` produced
  the expected two matching reads: one injected `-EPROTO`, one successful
  retry, `remaining=0`, `matching_calls=2`, and `missed=0`. Post-test traffic
  passed 10/10 in both directions.

## Known issues

- Target countries are not yet enumerated, so no production regulatory/EIRP
  profile has been approved. Denmark/EU is an example profile only.
- Secured payload validation is blocked until another stable RTL8812AU peer is
  available; RTL8192FU is retained only as an experimental open-mesh fixture.
- Original USB2 and independently powered-path endurance remain unvalidated.
- The current peer is RTL8192FU using `rtl8xxxu`; its intermittent multicast
  behavior cannot establish whether the remaining miss is in the RTL8192FU
  transmitter, RTL8812AU receiver, or the test transition timing.
