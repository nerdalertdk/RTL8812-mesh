# RTL8812AU mesh hardware-in-loop tests

Run the Pi scripts as root. They identify the two test radios by permanent MAC
and serialize topology changes through `/run/lock/rtw88-mesh-test.lock`.
Hardware test scripts require `flock` and fail closed if it is unavailable;
they never proceed with an unserialized radio or topology mutation.
Run `scripts/check-hardware-event-classifiers.sh` after changing any kernel-log
filter. It requires every functional gate to recognize the complete USB and
power signature set and verifies that the physical matrix retains its separate
transport and environmental-power classifications.
Set `ROOT_MAC` and `PEER_MAC` explicitly when invoking a script. For systemd
recovery, copy `rtw88-mesh-test.env.example` to
`/etc/default/rtw88-mesh-test`, replace both example addresses, and make the
same replacements in `99-rtw88-mesh-recover.rules` before installing it.
Both systemd units load `/etc/default/rtw88-mesh-test`; the soak unit will not
silently fall back to development adapter identities.
`pi_mesh_churn.sh` returns nonzero unless every join, peer link, cold contact,
multicast direction, and pair of HWMP path tables passes. Its binary multicast
reachability check sends three unacknowledged group frames and requires one;
the separate sender-captured probe enforces the quantitative >=99% gate.

`pi_mesh_multicast_probe.sh` quantifies group-frame delivery without changing
the active topology. It captures each burst at both sender and receiver, so a
missing frame can be localized to after the sender's network stack rather than
being reported only as a binary timeout. Run it only after an endurance service
has released the shared test lock.
It requires complete sender capture and defaults to at least 99% delivery in
each direction; lower delivery exits 1, incomplete sender evidence exits 2,
and a USB transport event exits 4 for review. Set `PEER_DRIVER=rtw_8812au` for
the production release gate so mixed-peer evidence cannot close it.

`pi_mesh_soak.sh` updates `latest.log` and `latest-summary.log` at run start.
The summary link intentionally remains dangling until the current run writes a
summary, preventing monitoring code from mistaking an older result for the
active run.
Its exit status is 0 only for a clean functional and kernel interval, 1 for a
workload failure, 4 for a functionally recovered transport/recovery event that
requires causal review, and 75 when the topology evidence is invalid or busy.
Interrupted runs preserve their incomplete summary and return the conventional
nonzero signal status instead of being reported as successful.
The physical USB matrix treats soak exit 4 as functionally complete and still
runs its final checksummed transfer before classifying the transport event.

Use `pi_mesh_soak_status.sh` for live monitoring. It derives the run ID from
`latest.log` and opens only the matching summary filename, so it also reports
correctly against hosts that still have an older deployed soak script whose
summary symlink points at a previous run.

`pi_mesh_soak_finalize.sh` waits for a detached systemd soak to exit, validates
the exact `SOAK_RUN_ID` summary's header, completion, state, ping, transfer,
invalidation, recovery, and kernel-event counters, and only then executes a
configured final integrity transfer. It opens
`soak-$SOAK_RUN_ID-summary.log` directly rather than following `latest`, so a
hard-killed run cannot inherit an older clean verdict. This also avoids relying
on `After=` to wait for a service that was already active when a dependent unit
was queued.

`pi_post_soak_dkms_build.sh` is a build-only continuation gate. Before waiting,
it requires an exact finalizer invocation, an empty dedicated transfer-result
directory, an unchanged source manifest, and an absent DKMS target version.
After that exact finalizer succeeds, it independently revalidates the clean
soak summary and bidirectional final transfer, reruns the source manifest, then
performs an exact-kernel `W=1` build and rejects compiler diagnostics. Only
after those gates pass does it register and build the five DKMS artifacts and
record their source versions, vermagic, and SHA-256. It never installs or loads
the result. `PREFLIGHT_ONLY=1` validates the queued operation without waiting or
writing DKMS state.

`pi_mesh_recover.sh` requires `EXPECTED_VERSION` and accepts recovery only
after `pi_module_provenance.sh` proves that exact DKMS package, all five loaded
`updates/dkms` modules, matching source versions/vermagic, and no unrelated
shared-core consumer. It then requires expected root/peer drivers, bilateral
`ESTAB`, successful
traffic in both directions, and nonempty HWMP tables at both peers. Its unit's
240-second start timeout covers the configured 90-second test-lock wait plus
the device enumeration and peering windows. Missing mesh-point capability or
an explicitly configured peer-driver mismatch exits 78 before topology
mutation; systemd does not restart that persistent environmental failure.

`pi_mesh_transfer.sh` is the standalone large-file integrity gate. Its default
is one 512 MiB random source transferred in both directions, with source and
destination SHA-256 comparison, curl timing/throughput metrics, post-transfer
HWMP validation, and kernel USB event capture. Temporary payloads are removed
on exit; the result log is retained under the configured `LOG_DIR` (default:
`/var/tmp/rtl8812au-mesh/mesh-transfer/`).
Set `PEER_DRIVER=rtw_8812au` for a production gate. A checksummed workload with
a kernel USB transport event exits 4 for causal review rather than being
reported as a clean pass.

The churn and channel-sweep gates use the same provenance and event convention:
peer-driver mismatch exits 2, functional failure exits 1, and any USB transport
event exits 4 while retaining the functional result in their output.

`pi_secure_mesh.sh` controls both peers with `wpa_supplicant`, requires both
control interfaces to reach `COMPLETED`, and proves SAE/AMPE from configured
SAE plus peer-specific SAE acceptance and decrypted AMPE in each log. This is
compatible with wpa_supplicant 2.10 returning `key_mgmt=UNKNOWN` in mesh
`STATUS`. It also requires bidirectional unicast, multicast, and HWMP paths.
Its default configuration is
`wpa_sae_mesh.conf`; the credential is intentionally public test data. To add
a checksummed transfer without deadlocking the shared test lock, set
`TRANSFER_TEST` to the absolute path of `pi_mesh_transfer.sh` and select the
size with `SECURE_FILE_MIB` (default 32 MiB). `ROOT_DRIVER` defaults to
`rtw_8812au`; set `PEER_DRIVER=rtw_8812au` for the release-gate run so the
result cannot accidentally be attributed to the experimental fixture. The
optional `PEER_DRIVER_ID` unbind fallback is only for a specifically identified
test adapter and is disabled by default.
Test supplicants are launched with directly tracked PIDs; an exact
test-specific process already present causes exit 75 rather than duplicate
nl80211 frame registration or unsafe process cleanup.
The secured gate retains its kernel interval in `KERNEL_LOG` and returns 4 if
an otherwise passing SAE/AMPE run contains a USB transport event requiring
causal review.

## RX submission-failure injection

`usb_rx_submit_failure.patch` is test-only instrumentation. Apply it only to a
disposable copy of the driver source; never include it in a production or
upstream build. It adds the root-writable `rtw_usb.test_rx_submit_failures`
module parameter and fails that many RX submissions with `-EPROTO` before the
URB reaches USB core. This safely exercises skb ownership clearing, delayed
retry, and retry-worker self-requeue; changing a successful `usb_submit_urb()`
return with kretprobe/BPF would be unsafe because the URB was actually queued.
The writable `test_rx_submit_success_mask` records which RX control blocks have
subsequently submitted successfully; clear it immediately before injection and
require `0xf` for the four-slot pool.

Example workflow in an isolated source copy:

```sh
patch -p1 < tests/usb_rx_submit_failure.patch
make -C /lib/modules/$(uname -r)/build M=$PWD rtw_usb.ko
# Load the complete matching local rtw88 stack, reconstruct the open mesh,
# start traffic, then inject more failures than the four-URB RX pool:
echo 0 > /sys/module/rtw_usb/parameters/test_rx_submit_success_mask
echo 8 > /sys/module/rtw_usb/parameters/test_rx_submit_failures
```

Required evidence:

- the parameter returns to zero;
- submit failures log delayed retry;
- `test_rx_submit_success_mask` becomes `15` (`0xf`), proving all four RX slots
  resume operation after the final injected failure;
- both peers remain or return to `ESTAB`;
- post-injection bidirectional traffic and a checksummed transfer pass;
- teardown/unbind during a pending retry completes without resubmission,
  warning, use-after-free, or workqueue activity after unregister.

The first completed run is recorded in
`results/2026-07-26-rx-submit-eproto.md`.

## TX failure injection

Before any behavioral or injection gate, run `pi_module_provenance.sh` with
`EXPECTED_VERSION` set to the intended production DKMS version. It requires the
exact package/kernel/architecture registration, all five modules loaded from
`updates/dkms`, matching installed and loaded `srcversion`, matching kernel
vermagic, recorded module-file SHA-256 values, and no unrelated `rtw_*` consumer
of the shared core namespace. Run it again after replacing disposable modules.

`usb_tx_failure_injection.patch` is test-only instrumentation for source 0.1.5
or an exact matching disposable copy. It adds root-writable
`rtw_usb.test_tx_submit_failures`,
`rtw_usb.test_tx_agg_submit_failures`, and
`rtw_usb.test_tx_completion_failures` parameters. The first fails a TX URB
before USB core sees it, proving generic synchronous submission ownership. The
second rejects only a real multi-frame aggregate and records its original-frame
count, proving the synthetic aggregate buffer follows the driver-owned cleanup
path. The third changes only the status delivered to the completion path;
the test frame may already have reached the adapter, so this is evidence for
status/cleanup handling and must not be interpreted as a physical USB fault.

Required evidence:

- all requested failure counts return to zero under sustained traffic;
- every requested aggregate-only rejection has a matching test marker, proving
  that an actual synthetic buffer and original-frame queue reached cleanup;
- every aggregate rejection has a post-cleanup marker reporting at least two
  original frames; the marker is emitted only after the unchanged production
  error path frees the synthetic transfer skb and drains the original-frame
  queue;
- each requested failure count is fully consumed; at least one rate-limited
  `USB TX URB error -71` diagnostic is retained for each injection phase, and
  displayed driver-counter values are positive and nonduplicated per adapter;
- bilateral mesh traffic resumes after submission injection and remains live
  after completion-status injection;
- strict churn and a bidirectional checksummed transfer pass after the
  disposable module is replaced by the exact production build;
- unload during and after injection produces no warning, leak symptom, stale
  work, or use-after-free signature.

Never ship or submit the instrumented source. A pre-submit injection is safe
because no URB was queued. A completion-status injection is deliberately not
replayed because the real transfer's device-side progress is ambiguous.

`pi_usb_tx_failure_test.sh` runs all three phases under the shared hardware lock.
It requires two RTL8812AU peers already in the open topology and fails closed
unless the test-only parameters exist. It drives traffic until all requested
counts reach zero, retains phase diagnostics, requires exact rejection and
post-cleanup markers for each aggregate-only failure, and requires positive,
nonduplicated cumulative counter values per adapter without imposing a global
order on messages from two devices or CPUs. It revalidates bilateral `ESTAB`,
traffic, and HWMP, and
rejects any kernel transport event other than its expected injected TX
`-EPROTO`. The script intentionally does not accept installed-module
provenance: the instrumented `rtw_usb` cannot match the production artifact.

`pi_usb_tx_teardown_test.sh` uses the same disposable build to prove TX
teardown against an actually active USB anchor. The test patch delays exactly
one completion for the selected USB interface by five seconds. The harness
drives concurrent large pings, waits until that callback enters its delay, then
unbinds the same RTL8812AU interface. It requires the pre-kill marker to show a
queued URB or active callback, the post-kill marker to show both counts at zero,
the synchronous unbind to finish inside an explicit wall-clock bound, no kernel
fault or transport signature, and a usable rebound netdev. The result records
unbind elapsed time. It fails
before taking the hardware lock or unbinding unless all disposable TX test
parameters are present and writable. Rebind queues the udev recovery service;
the harness stops that waiting unit before releasing its lock so the mesh
cannot be reconstructed with disposable code.
It deliberately does not reconstruct the mesh with the instrumented module.
Replace that module with exact production 0.1.5, then explicitly start recovery
before subsequent behavioral gates.

`scripts/check-test-instrumentation.sh` applies both disposable USB patches to
the exact production `usb.c` with strict whitespace handling. This prevents a
stale test patch from being mistaken for buildable current-source evidence.
Restore and provenance-check all five production modules before running churn
or transfer release gates.

`usb_ctrl_eproto_injector.c` targets only successful RTL8812AU vendor-device
control reads. It must never alter a completed write: a write may already have
changed device state, and reporting a synthetic failure afterward cannot undo
that side effect.

`pi_usb_ctrl_stress.sh` exercises the production control path with 16 parallel
readers and 1,024 total reads of the previously validated read-only register
`0x5a7` by default. It requires every debugfs result to be well formed, then
gates bilateral traffic, HWMP, and the kernel transport interval. Set
`PEER_DRIVER=rtw_8812au` when using it as production evidence.

Use `USB_PATH_MATRIX.md` for real `-71` experiments. It defines controlled
direct-USB3, direct-USB2, independently powered, repetition, logging, and causal
decision requirements so physical transport evidence is not conflated with
synthetic driver-retry evidence.

`pi_usb_path_trial.sh` executes one named matrix row/repetition. It keeps the
soak and final 512 MiB transfer under one lock, verifies the soak summary rather
than trusting its process exit alone, records pre/post module, topology, power,
temperature, and boot provenance, and preserves the complete kernel journal.
It returns 2 for invalid environmental or provenance evidence, 1 for a
valid-path workload/topology failure, 4 when a transport event requires causal
review, and 0 only when both workload stages pass without a transport event.
It rejects a pre-run historical soft-temperature bit because an already-set
bit cannot reveal a brief recurrence during the trial; reboot and establish
adequate cooling before starting physical attribution.
