# RTL8812AU mesh hardware-in-loop tests

Run the Pi scripts as root. They identify the two test radios by permanent MAC
and serialize topology changes through `/run/lock/rtw88-mesh-test.lock`.
`pi_mesh_churn.sh` returns nonzero unless every join, peer link, cold contact,
multicast direction, and pair of HWMP path tables passes.

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
