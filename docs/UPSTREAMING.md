# Upstreaming plan

The production delta against source base `a56bcd2` is confined to
`main.c`, `mac80211.c`, `usb.c`, and `usb.h`. Test instrumentation and Pi
recovery scripts are evidence tooling and must not be included in kernel
patches.

## Reproducible baseline

The original downstream source commit is
`a56bcd26e770257612a0803249cbd4095fc6feca`. The focused annotated tag
`upstream-baseline-a56bcd2` points to a synthetic commit containing only the
four production files at that exact revision. It deliberately avoids importing
the unrelated chipset and transport history into this package.

Verify the tag's four exact blob IDs and the current delta with:

```sh
./scripts/check-upstream-baseline.sh
git diff upstream-baseline-a56bcd2 -- main.c mac80211.c usb.c usb.h
```

The materialized eight-patch mail series is under `patches/`. Verify that it
applies in order with strict whitespace handling and reproduces the validated
production files byte-for-byte with:

```sh
./scripts/check-upstream-series.sh
```

The stored mail files intentionally use the neutral
`RTL8812AU Mesh Project <noreply@example.invalid>` identity and omit
`Signed-off-by` trailers so private development identity is not published by
this repository. They must not be sent upstream unchanged: the actual
submitter must regenerate or amend the mail headers, add their real Developer
Certificate of Origin sign-off, and retain the verified patch content.

Patch 7 is a complete fix relative to the repository's exact downstream
baseline, not a mail file that can be sent unchanged to current Linux
mainline. As checked on 2026-08-06, mainline already purges aggregate ownership
after synchronous submission failure and frees reserved/H2C skbs. It still
ignores TX completion status and does not anchor TX URBs. Rebase patches 7/8 on
the intended upstream tree, omit cleanup already present there, and retain the
completion-status/error-observability and anchored-teardown deltas. Re-run
strict checkpatch and hardware evidence against that rebased series.

Push the annotated tag together with the branch when publishing the repository;
a branch-only push cannot reproduce the baseline. The synthetic tag is a
review convenience, not a claim that its generated commit is the original
downstream commit.

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
   - Treat only the old-chip USB2-to-USB3 mode-switch write's deliberate
     disconnect statuses as expected; all other write failures remain errors.
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

7. **rtw88: handle USB TX failures without leaks or false ACKs**
   - Release aggregate TX contexts and queued skbs when URB submission fails.
   - Release reserved-page and H2C skbs when their submission fails.
   - Report TX completion errors to mac80211 without ACK.
   - Do not blindly replay an ambiguously submitted frame.

8. **rtw88: quiesce USB TX URBs before teardown**
   - Anchor every TX URB before submission.
   - Unanchor synchronously rejected submissions.
   - Drain the TX workqueue and kill every anchored URB before freeing driver
     state, so callbacks cannot outlive their skb or `rtwdev` context.

## Evidence expected with submission

- Exact-kernel clean build and module provenance for all five modules.
- Open mesh create/remove and strict peer churn.
- Bidirectional cold HWMP contact, group delivery, and transfer integrity.
- Software-crypto secured traffic with two stable RTL8812AU peers.
- Synthetic control-read and RX/TX submit/completion error handling.
- Pending-retry and in-flight-TX teardown with no post-unregister activity.
- Physical USB2/USB3 and independently powered-path repetitions separating
  driver recovery from hub, power, cable, and controller failures.

The last two hardware items remain release gates. Results obtained with the
experimental RTL8192FU peer are useful regression evidence but cannot prove
RTL8812AU-to-RTL8812AU secured interoperability.
