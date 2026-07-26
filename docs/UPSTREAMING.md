# Upstreaming plan

The production delta against source base `a56bcd2` is confined to
`main.c`, `mac80211.c`, `usb.c`, and `usb.h`. Test instrumentation and Pi
recovery scripts are evidence tooling and must not be included in kernel
patches.

## Proposed patch order

1. **rtw88: correct CAM capacity boundary**
   - Change the key index check from `>` to `>= total_cam_num`.
   - This is an independent bounds fix and should not be coupled to mesh.

2. **rtw88: admit RTL8812AU USB mesh-point interfaces**
   - Advertise mesh only for RTL8812A USB and only with
     `CONFIG_MAC80211_MESH` enabled.
   - Keep mesh out of the existing concurrency combination.
   - Honor `FIF_OTHER_BSS` together with beacon/probe promiscuity so mesh
     peers with different BSSIDs are visible.

3. **rtw88: use an access-category queue for mesh group frames**
   - Preserve the AP DTIM-oriented high queue for AP broadcast/multicast.
   - Select the normal access-category queue for mesh broadcast/multicast so
     ARP, multicast, and HWMP frames are transmitted immediately.

4. **rtw88: use software crypto for mesh per-peer keys**
   - Advertise the legacy-named `WIPHY_FLAG_IBSS_RSN` admission capability for
     per-peer non-pairwise mesh keys without claiming hardware per-STA GTK.
   - Reject mesh `SET_KEY` so mac80211 uses software crypto.
   - Succeed defensively for `DISABLE_KEY`, as required by mac80211.

5. **rtw88: make USB control reads deterministic and retry transient faults**
   - Clear the rotating buffer before each read.
   - Treat short reads as errors and retry only idempotent reads for bounded
     transient USB errors.
   - Do not retry writes whose device-side completion is ambiguous.
   - Serialize the complete synchronous control transaction. The original
     spinlock reserves only a ring index; it does not retain ownership of that
     buffer while a transfer or bounded retry is in flight.
   - Rate-limit diagnostics and retain cumulative counters.

6. **rtw88: retain RX capacity across recoverable USB failures**
   - Resubmit RX URBs after recoverable completion errors.
   - Retry transient submission/allocation failures with delayed work.
   - Clear skb ownership on failed submission.
   - Cancel retry work before URB teardown and again after callbacks have been
     quiesced, closing the completion-versus-teardown race.

## Evidence expected with submission

- Exact-kernel clean build and module provenance for all five modules.
- Open mesh create/remove and strict peer churn.
- Bidirectional cold HWMP contact, group delivery, and transfer integrity.
- Software-crypto secured traffic with two stable RTL8812AU peers.
- Synthetic control-read and RX submit/completion recovery.
- Pending-retry teardown with no post-unregister activity.
- Physical USB2/USB3 and independently powered-path repetitions separating
  driver recovery from hub, power, cable, and controller failures.

The last two hardware items remain release gates. Results obtained with the
experimental RTL8192FU peer are useful regression evidence but cannot prove
RTL8812AU-to-RTL8812AU secured interoperability.
