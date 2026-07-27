# Session

## Current focus

Complete the active DKMS 0.1.2 endurance run, then build and validate source
DKMS 0.1.3 with deterministic USB control-transaction buffer ownership and
close the hardware gates requiring a second RTL8812AU or powered USB paths.

The deployment requirement is now also recorded: multinational, off-grid
mobile MANET operation with an approximate 1 km LOS target at 2.4 GHz HT20.

## Current status

- The final eight-hour DKMS 0.1.2 run completed before a later power loss:
  597/597 states established, 1,194/1,194 ping batches and 16/16 checksummed
  transfers passed, with zero recovery windows, invalidations, or measured
  USB events. Sticky `0xe0000` power history prevents using it as clean
  power-path evidence. See
  `tests/results/2026-07-27-eight-hour-soak-power-cycle.md`.
- The later boot exposed two distinct conditions. The experimental RTL8192FU
  reverted to distro `rtl8xxxu`, which does not advertise mesh, so recovery
  now rejects it before topology mutation with non-restarting exit 78. The
  RTL8812AU USB2-to-USB3 mode switch also produced an expected `-EPROTO` on
  the deliberate disconnect write to register `0x5`; source 0.1.3 now
  excludes only that narrow event from generic control-failure accounting.

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
- Upstream-semantics review found that the mesh software-crypto fallback
  returned `-EOPNOTSUPP` for both `SET_KEY` and `DISABLE_KEY`, although
  mac80211 requires `DISABLE_KEY` to succeed. DKMS 0.1.2 rejects only mesh key
  installation and returns success for defensive removal calls.
- RX teardown review found a race in which a completion could queue delayed
  retry work after the pre-kill cancellation. DKMS 0.1.2 performs a second
  synchronized cancellation after all RX URB callbacks are quiesced.
- DKMS 0.1.2 exact-kernel build, install, and loaded provenance checks passed.
  Recovery restored `ESTAB` in five seconds and a strict 20-cycle churn run
  passed every join, plink, cold-contact, multicast, and dual-HWMP gate with
  zero USB errors.
- On a disposable instrumented 0.1.2 build, eight synthetic RX submit
  `-EPROTO` failures were consumed, all four RX slots recovered (`0xf`), and
  traffic passed 40/40 both directions. A full unload began with 99,980
  failures still pending, completed with production reload in 857 ms, and
  produced no warning/Oops/UAF/refcount/workqueue-after-free signature.
  Production provenance matched and post-recovery traffic passed 10/10 both
  directions.
- The four-file production delta passed an exact-kernel `W=1` build and Linux
  v6.12 strict checkpatch with zero errors, warnings, or checks. Comparison
  with Linux v6.12 and current mainline confirmed that upstream still lacks
  the package's deterministic control-read and recoverable RX-URB handling.
  A suspected partial-allocation cleanup fault was rejected because Linux USB
  core explicitly permits NULL for both `usb_kill_urb()` and `usb_free_urb()`.
  No code change or DKMS bump was warranted. See
  `tests/results/2026-07-26-upstream-static-audit.md`.
- USB control-context audit confirmed `usb_control_msg()` is task-context and
  may sleep. The former spinlock protected only selection from a 128-buffer
  ring, not the selected buffer across a retryable transaction lasting up to
  roughly three seconds. Source DKMS 0.1.3 uses a mutex across the complete
  read/write transaction, eliminating wrap-based buffer aliasing. Build,
  injection, and hardware regression are queued after the 0.1.2 soak.
- The secured-mesh harness now queries the nondefault control socket it
  configures, requires `wpa_state=COMPLETED` and `key_mgmt=SAE` at both peers,
  and gates bidirectional multicast plus HWMP. It can invoke the checksummed
  transfer harness while safely inheriting the already-held topology lock.
  Raspberry Pi `dash -n` and wpa_supplicant 2.10 configuration parsing pass;
  live validation remains gated on a second stable RTL8812AU.
- Secured-harness control-flow review found that root driver provenance was
  queried through the old sysfs netdev name after a rename. It now captures
  the driver before renaming, preventing a false pre-SAE abort on the current
  Pi naming layout.
- Earlier mixed-peer SAE logs were causally reviewed. RTL8812AU started the
  secured group, accepted software MGTK handling, repeatedly received peer
  commits, and completed defensive key removal. RTL8192FU failed
  secured-beacon setup with `-EOPNOTSUPP`, so RTL8812AU never discovered it
  and correctly dropped authentication from an unknown mesh peer. The onboard
  `brcmfmac` firmware
  does not advertise mesh mode. See
  `tests/results/2026-07-26-secure-mixed-peer-diagnostic.md`; the two-RTL8812AU
  gate remains open.
- The secured gate now preserves the complete kernel interval and returns 4
  when SAE/AMPE traffic passes but a USB transport event occurred, preventing
  recovery from being silently reported as a clean security run.
  Its interval closes before open-topology recovery, so a deliberate fallback
  unbind cannot be misclassified as a secured-mesh transport fault.
- Packaging consistency review removed the stale claim that hardware scripts
  contain development MAC defaults and made the soak systemd unit load the
  same required `/etc/default/rtw88-mesh-test` identity file as recovery.
- Secured preflight now discovers and validates both radio drivers before any
  netdev mutation. Pi checks proved that a missing root and the expected
  `rtl8xxxu`-versus-`rtw_8812au` peer mismatch both exit without invoking
  recovery or disturbing the active soak.
- Recovery now rejects wrong radio drivers or any installed/loaded source
  version mismatch before topology mutation, and reports success only after
  bilateral peering, traffic, and HWMP validation. Pi preflight tests proved
  both the peer-driver and injected module-provenance rejection paths without
  disturbing the active soak. The systemd timeout is aligned to the script's
  worst-case lock and enumeration windows; a full reconstruction test is
  queued after the soak releases the hardware lock.
- Multicast probing now has an explicit release contract: complete sender
  capture, at least 99% delivery in each direction, optional required peer
  driver provenance, and distinct failure, invalid-evidence, and USB-event
  review exits. This keeps best-effort group delivery measurable without
  allowing a diagnostic script's former unconditional success to close a gate.
- Churn, channel sweep, and checksummed transfer now share the same contract:
  optional required peer-driver provenance and exit 4 when a functional pass
  contains a USB transport event. This prevents recovered `-71` evidence from
  being flattened into an ordinary clean pass.
- Every hardware-test entry point now fails closed when `flock` is unavailable,
  preserving the repository-wide single-owner topology invariant. Churn also
  defines its namespace helper before peer-driver provenance is evaluated.
  Debian prerequisites now name `util-linux` as the provider of mandatory
  `flock` support.
- Repository soak summaries now include a numeric kernel transport-event count.
  A functionally complete run with a transport event or recovery window exits
  4, and the USB matrix treats that as functionally complete so its final
  checksummed transfer still runs before causal classification.
  SIGINT/SIGTERM also retain an incomplete summary but no longer exit 0.
- The Pi's currently running soak executable predates the repository's
  run-start `latest-summary.log` update, so its summary link still names the
  prior stopped run. `pi_mesh_soak_status.sh` now derives the active run ID
  from `latest.log` and will only consume the corresponding summary. It was
  validated against both the live pending run and the prior completed run.
  Replace the deployed soak executable only after the active process exits.
- `docs/RELEASE_GATES.md` now maps every Debian mesh, security, endurance, USB
  recovery, physical attribution, and upstream-hygiene requirement to its
  authoritative evidence. It prevents mixed-peer and synthetic tests from
  being used to overclaim the still-pending two-RTL8812AU and powered-path
  gates.
- `pi_usb_path_trial.sh` now turns each physical USB matrix row/repetition into
  one serialized evidence bundle. It validates negotiated row speed and Pi
  path shape, all five module source versions, the soak summary, final
  checksummed transfer, post-run topology, power history, and kernel events.
  Clean, workload-failure, environmental/provenance-invalid, and recovered or
  disruptive transport-event results are distinct. A non-disruptive row-A Pi
  dry-run passed topology/provenance checks and correctly classified its inert
  workload as failure; inherited-lock handling was also verified without
  touching the live radios.
- The repository soak now records an explicit completion marker and returns
  nonzero after a timed run unless every state is established and all ping,
  transfer, HWMP, and invariant counters pass. This prevents systemd success
  from being mistaken for a passing endurance result. The active Pi process
  uses the older deployed inode and is intentionally left undisturbed.

## Known issues

- Target countries are not yet enumerated, so no production regulatory/EIRP
  profile has been approved. Denmark/EU is an example profile only.
- Secured payload validation is blocked until another stable RTL8812AU peer is
  available; RTL8192FU is retained only as an experimental open-mesh fixture.
- Original USB2 and independently powered-path endurance remain unvalidated.
- The current peer is RTL8192FU using `rtl8xxxu`; its intermittent multicast
  behavior cannot establish whether the remaining miss is in the RTL8192FU
  transmitter, RTL8812AU receiver, or the test transition timing.
