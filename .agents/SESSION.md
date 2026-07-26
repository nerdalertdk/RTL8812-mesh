# Session

## Current focus

Complete and review a production-driver eight-hour mesh endurance run.

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

## Known issues

- Target countries are not yet enumerated, so no production regulatory/EIRP
  profile has been approved. Denmark/EU is an example profile only.
- Secured payload validation is blocked until another stable RTL8812AU peer is
  available; RTL8192FU is retained only as an experimental open-mesh fixture.
- Original USB2 and independently powered-path endurance remain unvalidated.
- The current peer is RTL8192FU using `rtl8xxxu`; its intermittent multicast
  behavior cannot establish whether the remaining miss is in the RTL8192FU
  transmitter, RTL8812AU receiver, or the test transition timing.
