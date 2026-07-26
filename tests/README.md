# RTL8812AU mesh hardware-in-loop tests

Run the Pi scripts as root. They identify the two test radios by permanent MAC
and serialize topology changes through `/run/lock/rtw88-mesh-test.lock`.
Set `ROOT_MAC` and `PEER_MAC` explicitly when invoking a script. For systemd
recovery, copy `rtw88-mesh-test.env.example` to
`/etc/default/rtw88-mesh-test`, replace both example addresses, and make the
same replacements in `99-rtw88-mesh-recover.rules` before installing it.
`pi_mesh_churn.sh` returns nonzero unless every join, peer link, cold contact,
multicast direction, and pair of HWMP path tables passes.

`pi_mesh_multicast_probe.sh` quantifies group-frame delivery without changing
the active topology. It captures each burst at both sender and receiver, so a
missing frame can be localized to after the sender's network stack rather than
being reported only as a binary timeout. Run it only after an endurance service
has released the shared test lock.

`pi_mesh_soak.sh` updates `latest.log` and `latest-summary.log` at run start.
The summary link intentionally remains dangling until the current run writes a
summary, preventing monitoring code from mistaking an older result for the
active run.

Use `pi_mesh_soak_status.sh` for live monitoring. It derives the run ID from
`latest.log` and opens only the matching summary filename, so it also reports
correctly against hosts that still have an older deployed soak script whose
summary symlink points at a previous run.

`pi_mesh_transfer.sh` is the standalone large-file integrity gate. Its default
is one 512 MiB random source transferred in both directions, with source and
destination SHA-256 comparison, curl timing/throughput metrics, post-transfer
HWMP validation, and kernel USB event capture. Temporary payloads are removed
on exit; the result log is retained under the configured `LOG_DIR` (default:
`/var/tmp/rtl8812au-mesh/mesh-transfer/`).

`pi_secure_mesh.sh` controls both peers with `wpa_supplicant`, verifies that
both control interfaces reached `COMPLETED` with SAE, and requires
bidirectional unicast, multicast, and HWMP paths. Its default configuration is
`wpa_sae_mesh.conf`; the credential is intentionally public test data. To add
a checksummed transfer without deadlocking the shared test lock, set
`TRANSFER_TEST` to the absolute path of `pi_mesh_transfer.sh` and select the
size with `SECURE_FILE_MIB` (default 32 MiB). `ROOT_DRIVER` defaults to
`rtw_8812au`; set `PEER_DRIVER=rtw_8812au` for the release-gate run so the
result cannot accidentally be attributed to the experimental fixture. The
optional `PEER_DRIVER_ID` unbind fallback is only for a specifically identified
test adapter and is disabled by default.

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

`usb_ctrl_eproto_injector.c` targets only successful RTL8812AU vendor-device
control reads. It must never alter a completed write: a write may already have
changed device state, and reporting a synthetic failure afterward cannot undo
that side effect.

Use `USB_PATH_MATRIX.md` for real `-71` experiments. It defines controlled
direct-USB3, direct-USB2, independently powered, repetition, logging, and causal
decision requirements so physical transport evidence is not conflated with
synthetic driver-retry evidence.
