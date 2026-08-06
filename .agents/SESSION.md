# Session

## Current focus

Finish the symmetric DKMS 0.1.4 endurance baseline, then build and qualify
source DKMS 0.1.5 with deterministic USB TX submission, completion, and
in-flight teardown evidence before repeating the mesh behavior gates.

The default 2.4 GHz deployment profile is now USB2 with
`rtw_usb.switch_usb_mode=N` after the pending physical USB2 gates pass; USB3
remains an explicit required regression profile.

The deployment requirement is now also recorded: multinational, off-grid
mobile MANET operation with an approximate 1 km LOS target at 2.4 GHz HT20.

## Current status

- Hardware event classifiers are now statically verified. The audit found and
  fixed missing undervoltage detection in the quantitative multicast gate and
  missing undervoltage/overcurrent detection in the SAE/AMPE gate;
  `scripts/check-hardware-event-classifiers.sh` reports all ten functional
  gates and the split physical-matrix classification complete.
- Source DKMS 0.1.5 fixes a USB TX error-path bug found during the symmetric
  soak: failed aggregate submissions previously leaked the TX context and
  queued skbs, reserved/H2C submission failures leaked their skb, and errored
  completions were reported as successful. The new path releases ownership and
  reports no ACK without blindly replaying an ambiguously submitted frame.
  TX URBs are now anchored before submission and killed synchronously after
  the TX producer is drained, closing a completion-after-free window during
  unbind and probe cleanup. Exact-kernel build, targeted fault injection,
  pending-TX unbind, and hardware regression are pending until the active
  0.1.4 soak releases the Pi. Static findings, Linux USB-anchor contract, and
  the pending evidence boundary are recorded in
  `tests/results/2026-08-06-usb-tx-error-audit.md`.
  A further ownership audit found that inherited aggregation put the
  driver-allocated transfer skb into mac80211's TX-status queue alongside the
  original frames. Normal completion reported that synthetic buffer with an
  invalid control block, and submission rejection passed it to mac80211's
  free path. Source 0.1.5 now tracks and frees the aggregate buffer separately;
  only original frames enter status or purge paths. Both downstream and pinned
  mainline patch series reproduce this corrected production source and pass
  strict checkpatch 0/0/0.
  The serialized `pi_usb_tx_failure_test.sh` harness is deployed for the
  disposable build. Its counter validator now keys values per USB adapter,
  allowing legitimate equal values from two device-local counters while still
  rejecting duplicates for one adapter. A third deterministic phase now
  rejects only a populated multi-frame aggregate, requires exactly one marker
  per requested rejection, and thereby proves split aggregate/original cleanup
  instead of assuming a generic injected submission happened to aggregate.
  Its deployed SHA-256 is
  `026d7e14e05df7935c7e33fe703442a2502d46a0fe6401f5799015ea775ef44a`.
  Against the currently loaded
  uninstrumented 0.1.4 module
  it exited 2 at the required-parameter preflight, before taking the hardware
  lock or disturbing either active endurance service.
  Current Linux mainline independently contains synchronous aggregate and
  reserved/H2C submission cleanup, but still lacks completion-status handling
  and TX URB anchoring. Production 0.1.5 now follows mainline's
  mac80211-aware purge semantics. The pinned mainline form also continues
  draining frames already queued by mac80211 after a synchronous submission
  rejection; otherwise mainline's false return stops the worker at the first
  recoverable transport error. Patches 7/8 must omit cleanup already landed
  before an actual upstream submission.
  The aggregate-only gate now also requires one post-cleanup marker per
  rejection and at least two original frames in every marker. Injection only
  records the expected frame count; both frees remain in the unchanged
  production error path, and the marker is emitted after the synthetic
  transfer skb is freed and the original-frame queue is drained. This closes
  the earlier gap where reaching the rejection branch did not itself prove
  runtime cleanup execution.
  A TX-only two-patch rebase is now pinned under `patches/mainline/` to Linux
  commit `315f4bd234b3b8a3ed3a71fd4c53b110cf373720`. Its offline verifier checks
  both exact baseline files, strict patch application, and both final hashes;
  the rebased patches pass strict v6.12 checkpatch 0/0/0.
  Exact pinned Linux USB-core review confirms that giveback suspends anchor
  wakeups before unanchoring, invokes the driver callback, then resumes anchor
  wakeups; the kill waits for both the URB list and that active-callback count.
  Disposable TX instrumentation deterministically delays one completion for a
  selected USB interface by five seconds and logs queued-URB and callback counts
  before and after the kill. The serialized `pi_usb_tx_teardown_test.sh` starts
  that callback, unbinds the same adapter, requires in-flight state before and
  zero state after the kill, rejects fault/transport signatures, stops the
  udev-queued recovery unit while holding the lock, and requires a successful
  rebind. Both disposable USB patches are now
  apply-checked against exact production `usb.c` by
  `scripts/check-test-instrumentation.sh`. The teardown harness fails before
  acquiring the hardware lock or unbinding unless all disposable module
  parameters exist; an earlier preflight returned exit 2 against uninstrumented
  0.1.4 while the soak remained active. Synchronous sysfs unbind is guarded by
  an explicit 20-second timeout plus five-second kill grace, and successful
  results record elapsed unbind time. Pi coreutils support and the fail-closed
  preflight were rechecked after deployment. Its SHA-256 is
  `f9430642110a5937739f8dc96f81118c7fd2e064bd44effc446e2b077c51e6a0`;
  the deployed injector patch SHA-256 is
  `69f7a8be35d69dce1c84a191489fc7357795f6f1500e7e77201c3a4787326316`;
  it passes exact pinned Linux strict checkpatch with 0/0/0.
- An eight-hour two-RTL8812AU functional endurance run started at
  2026-08-06 20:34 CEST as `rtw88-two-rtl8812au-soak.service`, with expected
  completion around 2026-08-07 04:34 CEST. Its first bilateral `ESTAB`/HWMP
  state, 10/10 ping batches in both directions, and bidirectional checksummed
  10 MiB transfers passed. The live log is under
  `/var/tmp/rtl8812au-mesh/two-rtl8812au-soak/` on the Pi. Historical thermal
  bit 19 means this is functional endurance, not a clean physical-path matrix
  repetition; the live 85 C cutoff remains enforced.
  A detached `pi_mesh_soak_finalize.sh` service waits for this exact soak,
  validates its matching clean summary, and then runs the bidirectional 512 MiB
  integrity gate. The finalizer is bound to run ID `20260806T183421Z` and opens
  that summary directly, so a hard-killed run cannot inherit an older clean
  `latest-summary.log` verdict. Its replacement invocation ID is
  `614d2c1f1c5444ca805fe0d8e08e0258`. It replaces an invalid `After=` attempt
  that started immediately, found the held test lock, and performed no
  transfer.
  Its second hourly checkpoint at 22:35 CEST passed cumulative 151/151
  bilateral established/HWMP states, 302/302 directional ping batches, and
  6/6 checksummed transfers. The latest 10 MiB pair matched SHA-256 at
  4,903,833 B/s root-to-peer and 5,071,523 B/s peer-to-root. Temperature ranged
  from 75.958 to 79.367 C; there were zero recovery windows, invalidations,
  USB/power events, or workload failures.
- The exact aggregate-ownership-corrected source 0.1.5 tree is staged without
  build artifacts or private agent context at
  `/var/tmp/rtl8812au-mesh/source-0.1.5-0ee949f/` on the Pi. Its root build-input
  manifest is `d42cf46e688f738674fc7d1d56d1a2e05c221cc6f046bc0e30d3e590459263a3`
  and matches the repository exactly. The earlier `source-0.1.5-29f0a15/`,
  `source-0.1.5-93103a0/`, and `source-0.1.5-9fbffb3/` directories are
  superseded and must not be built.
- Two RTL8812AU adapters now form the production test fixture, one at USB3
  `5000M` and one at USB2 `480M`, both on `rtw_8812au` with native mesh-point
  capability. Open recovery validates bilateral traffic and reciprocal HWMP.
  The new read-only `pi_module_provenance.sh` gate passed against live 0.1.4
  during the soak: exact DKMS kernel/architecture registration, five loaded
  `updates/dkms` paths, matching installed/loaded source versions and vermagic,
  recorded file hashes, and zero unrelated shared-core consumer. Its deployed
  SHA-256 is
  `98403c9a7a4edf080ff44cc97b56cb40be198a9280683ff6eb38d6f398ee2256`;
  the same gate is mandatory before and after disposable 0.1.5 testing.
- Symmetric multicast passed the sender-captured release gate at 399/400 and
  400/400 delivered frames with zero USB events. A single-frame churn probe
  produced 19/20 twice; a three-frame reachability burst, with the separate
  >=99% quantitative gate retained, passed strict churn 20/20 throughout.
- A symmetric bidirectional 512 MiB transfer matched SHA-256 at 3.97 and
  5.14 MB/s with reciprocal HWMP and no USB event.
- Symmetric SAE/AMPE passed peer-specific SAE acceptance, decrypted AMPE,
  MFP/authorization, 20/20 pings each way, multicast both ways, HWMP, and a
  bidirectional checksummed 32 MiB transfer. The harness now handles
  `wpa_supplicant` 2.10's mesh `key_mgmt=UNKNOWN` status and directly tracks
  the namespace supplicant so cleanup cannot orphan it. See
  `tests/results/2026-08-06-two-rtl8812au-qualification.md`.
- The two-RTL8812AU channels 1--13 HT20 sweep passed 13/13 under DK, including
  bilateral fresh peering, cold unicast, multicast reachability, reciprocal
  HWMP, channel-1 restoration, and a zero-event USB interval.
- The Pi recorded historical soft-temperature limiting (`0x80000`) at
  79.8--80.8 C, without undervoltage. Use active cooling before long endurance
  or physical USB attribution runs.
- Upstream provenance is now reproducible inside the focused repository. The
  annotated `upstream-baseline-a56bcd2` tag contains exactly the four original
  production blobs from full source commit `a56bcd26e770257612a0803249cbd4095fc6feca`;
  `scripts/check-upstream-baseline.sh` verifies their IDs and the production
  diff. Publish the tag with the branch.
- The eight logical production changes are materialized as ordered mail patches
  under `patches/`. `scripts/check-upstream-series.sh` reapplies them from the
  tagged baseline with strict whitespace handling and requires all four final
  files to match the validated production tree byte-for-byte.
- Physical USB trial preflight now rejects a pre-existing Raspberry Pi bit 19
  soft-temperature history. Once that bit is already set, a brief recurrence
  cannot be inferred from the post-run mask after the current bit clears, so a
  reboot and adequate cooling are mandatory before attribution.
  A Pi row-A dry preflight returned exit 2 with
  `invalid-pre-run-environment-state` for `0x80000` and created no soak
  directory, proving rejection occurs before workload launch.

- DKMS 0.1.4 built and installed exactly five modules for
  `6.12.47+rpt-rpi-v8`; all loaded and installed source versions match. An
  exact-kernel `W=1` rebuild and strict checkpatch both passed cleanly.
- The 0.1.4 control mutex passed 1,024/1,024 parallel register reads and a
  read-only injected `-EPROTO` recovered on attempt two with no missed match.
  Bilateral traffic, `ESTAB`, and reciprocal HWMP paths remained intact.
- A durable 20-cycle 0.1.4 churn run passed every join, first-contact,
  multicast, and dual-HWMP gate with no USB event. A bidirectional 512 MiB
  transfer then passed matching SHA-256 at 8.93 and 10.21 MB/s with no event.
- Hardened recovery rejects a mesh-incapable peer with exit 78 before mutation.
  After restoring the mesh-enabled experimental peer module, udev recovery
  reconstructed and validated the topology in ten seconds.
- The bounded ten-minute 0.1.4 soak completed naturally: 12/12 bilateral
  established/HWMP samples, 24/24 ping batches, and 8/8 checksummed 32 MiB
  transfers passed with zero recovery, invalidation, or kernel transport event.
  Detailed evidence is in
  `tests/results/2026-07-27-dkms-0.1.4-validation.md`.

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
  the deliberate disconnect write to register `0x5`; source 0.1.4 now
  excludes only that narrow event from generic control-failure accounting.
  The hardened helper/unit are deployed; a live unsupported-peer invocation
  exited `78/CONFIG` with `NRestarts=0`.

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
  roughly three seconds. Source DKMS 0.1.4 uses a mutex across the complete
  read/write transaction, eliminating wrap-based buffer aliasing. Build,
  injection and hardware regression are in progress after the 0.1.2 soak.
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
- The powered/direct USB path matrix and a thermally clean long endurance run
  remain open release gates.
- Original USB2 and independently powered-path endurance remain unvalidated.
- The current peer is RTL8192FU using `rtl8xxxu`; its intermittent multicast
  behavior cannot establish whether the remaining miss is in the RTL8192FU
  transmitter, RTL8812AU receiver, or the test transition timing.
