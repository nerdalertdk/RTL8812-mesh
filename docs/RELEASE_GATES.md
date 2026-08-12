# RTL8812AU mesh release gates

This matrix defines the evidence required before the Debian driver can be
called robust for native IEEE 802.11s. A passing mixed-adapter result is useful
regression evidence, but cannot substitute for an RTL8812AU-to-RTL8812AU gate.

| Requirement | Required evidence | Current evidence | Status |
| --- | --- | --- | --- |
| Exact-kernel Debian package | All five DKMS modules build, install, load from `updates/dkms`, match kernel vermagic and installed `srcversion`, and have recorded hashes with no unrelated shared-core consumer | DKMS 0.1.5 passed exact `W=1` and DKMS build-only gates, then installed and loaded on `6.12.47+rpt-rpi-v8`; five-module provenance, hashes, and `srcversion` fields matched exactly | Pass |
| Open mesh peering | Repeated fresh joins with both peer links `ESTAB` | DKMS 0.1.5 strict 20-cycle churn passed 20/20 with bilateral mesh peering | Pass |
| Cold HWMP discovery | Bidirectional first contact after path/neighbour flush and paths at both peers | DKMS 0.1.5 strict churn passed 20/20 with reciprocal HWMP paths; its channel sweep remains pending | Pass for the HT20 default profile; channel sweep pending |
| Open unicast integrity | Checksummed large payload in both directions | DKMS 0.1.4 transferred 512 MiB each direction with matching SHA-256 and no kernel event; repeat on 0.1.5 | Pass on 0.1.4; 0.1.5 regression pending |
| Open group traffic | Complete sender capture and at least 99% bidirectional delivery with two stable RTL8812AU radios | DKMS 0.1.5 passed qualitative binary multicast/churn. Four 400-frame probes were below 99% on branch `1-1.2`, but moving the same adapter to `1-1.1` passed 399/400 and 400/400 with no transport event. The regression is localized to a physical branch, but the controlled USB matrix remains incomplete | Pass for `1-1.1`/`1-1.4`; physical matrix pending |
| SAE/AMPE | Both peers prove completed SAE and decrypted AMPE, then pass bidirectional unicast, multicast, HWMP, and checksummed payload | DKMS 0.1.4 proved peer-specific SAE acceptance/decrypted AMPE and passed secured traffic/HWMP/checksums; repeat a secured smoke on 0.1.5 | Pass on 0.1.4; 0.1.5 regression pending |
| 2.4 GHz HT20 channels | Fresh peering, cold traffic, multicast reachability, and HWMP on every channel allowed by the selected test regulatory profile | DKMS 0.1.4 passed channels 1--13 under DK with no USB event; current-source channel sweep remains required | Pass on 0.1.4; 0.1.5 sweep pending |
| 2.4 GHz HT40 compatibility | Where regulatory domain, channel pairing, and coexistence rules permit it: open peering, HWMP, sender-captured multicast, SAE/AMPE, transfer, and short churn with two RTL8812AU peers | Not yet tested | Pending |
| 5 GHz HT20 compatibility | Open peering, HWMP, sender-captured multicast, SAE/AMPE, transfer, and short churn on permitted 5 GHz channels with two RTL8812AU peers | Not yet tested | Pending |
| 5 GHz HT40 compatibility | Same as 5 GHz HT20 at 40 MHz where permitted, including DFS handling when the selected channel requires it | Not yet tested | Pending |
| Transient control `-EPROTO` | Read-only injected fault is consumed by bounded retry; no write injection | Two matching reads, injected failure followed by successful retry, no miss | Pass |
| RX submit recovery | Every RX slot recovers after injected transient failures; traffic remains valid | Eight failures consumed, success mask `0xf`, 40/40 pings each way | Pass |
| Retry teardown safety | Unload while retries are pending with no post-free work, warning, Oops, or UAF | Unload with 99,980 failures pending; production reload in 857 ms; no kernel fault signature | Pass |
| TX submission/completion errors | Driver-owned aggregate buffers never enter mac80211 status/purge paths; failed submissions release all callback-owned state; completion errors report no false ACK and are observable without blind replay | Disposable 0.1.5 injection passed pre-submit rejection, populated aggregate rejection with post-cleanup proof, and completion `-EPROTO` with the post-status exact-count marker | Pass (disposable fault gate) |
| TX teardown safety | Every submitted TX URB is quiesced before skb, mac80211, or driver state is freed | Disposable selected-device test proved USB core serializes remove after an active completion; post-kill anchor and callback counts were zero and rebind was bounded, with no lifetime fault signature | Pass (disposable teardown gate) |
| Physical USB fault attribution | Three valid repetitions for direct USB3, direct USB2, powered USB3, and powered USB2 with topology/power/event logs | Matrix, causal rules, and serialized evidence runner exist; independently powered paths unavailable | Pending hardware |
| Endurance | Bounded unattended run with peer/HWMP state, traffic, checksums, recovery, USB events, temperature, and power flags | Symmetric DKMS 0.1.4 completed 597/597 states, 1,194/1,194 ping batches, and 16/16 transfers with zero recovery, invalidation, or kernel event; 0.1.5 long regression has not run | Pass on 0.1.4; 0.1.5 endurance pending |
| Upstream hygiene | Reviewable patch split, exact-kernel warning build, strict checkpatch, and comparison with current kernel behavior | Nine downstream and pinned wireless-next patches reproduce production byte-for-byte; a two-patch TX-only series against pinned Linux `315f4bd234b3` reproduces exact final hashes. Static qualification, including exact-kernel `W=1`/DKMS build-only contracts, passes | Pass for repository hygiene; upstream review still required |

## Completion rule

Release readiness requires every row to pass at its stated scope. Behavioral
evidence must match the current production source or be
explicitly repeated after a production change that can affect that behavior;
a previously qualified package version is regression history, not qualification
of a newer unbuilt DKMS package. In particular, synthetic USB recovery proves
driver behavior but cannot establish
whether real `-71` events originate in the adapter, cable, hub, host
controller, or power path. Likewise, an RTL8192FU peer cannot close the
RTL8812AU interoperability, secured group-key, or symmetric multicast gates.
For hardware gates, exit 0 means both the workload and the observed kernel
interval were clean. Exit 4 preserves a potentially recovered transport event
for causal review and is not a clean release pass.
The endurance soak records a numeric kernel-event count and returns exit 4 when
the workload completes after any transport event or recovery window. A physical
USB-path trial must still complete its final checksummed transfer in that case
before it classifies the event as recovered.
