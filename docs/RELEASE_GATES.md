# RTL8812AU mesh release gates

This matrix defines the evidence required before the Debian driver can be
called robust for native IEEE 802.11s. A passing mixed-adapter result is useful
regression evidence, but cannot substitute for an RTL8812AU-to-RTL8812AU gate.

| Requirement | Required evidence | Current evidence | Status |
| --- | --- | --- | --- |
| Exact-kernel Debian package | All five DKMS modules build, install, load, and match installed `srcversion` values | DKMS 0.1.4 passed on `6.12.47+rpt-rpi-v8`; repository source is now 0.1.5 and has not been built or loaded | Pending current-source build |
| Open mesh peering | Repeated fresh joins with both peer links `ESTAB` | DKMS 0.1.4 strict 20-cycle churn passed 20/20; repeat required after loading 0.1.5 | Pass on 0.1.4; 0.1.5 regression pending |
| Cold HWMP discovery | Bidirectional first contact after path/neighbour flush and paths at both peers | DKMS 0.1.4 strict churn passed 20/20; channel sweep passed channels 1--13; repeat strict churn on 0.1.5 | Pass on 0.1.4; 0.1.5 regression pending |
| Open unicast integrity | Checksummed large payload in both directions | DKMS 0.1.4 transferred 512 MiB each direction with matching SHA-256 and no kernel event; repeat on 0.1.5 | Pass on 0.1.4; 0.1.5 regression pending |
| Open group traffic | Complete sender capture and at least 99% bidirectional delivery with two stable RTL8812AU radios | DKMS 0.1.4 delivered 399/400 and 400/400 with complete sender capture; revised churn passed 20/20; repeat churn after 0.1.5 TX changes | Pass on 0.1.4; 0.1.5 regression pending |
| SAE/AMPE | Both peers prove completed SAE and decrypted AMPE, then pass bidirectional unicast, multicast, HWMP, and checksummed payload | DKMS 0.1.4 proved peer-specific SAE acceptance/decrypted AMPE and passed secured traffic/HWMP/checksums; repeat a secured smoke on 0.1.5 | Pass on 0.1.4; 0.1.5 regression pending |
| 2.4 GHz HT20 channels | Fresh peering, cold traffic, multicast reachability, and HWMP on every channel allowed by the selected test regulatory profile | DKMS 0.1.4 passed channels 1--13 under DK with no USB event; TX selection is unchanged in 0.1.5, but current-source build/regression remains required | Pass on 0.1.4; 0.1.5 smoke pending |
| Transient control `-EPROTO` | Read-only injected fault is consumed by bounded retry; no write injection | Two matching reads, injected failure followed by successful retry, no miss | Pass |
| RX submit recovery | Every RX slot recovers after injected transient failures; traffic remains valid | Eight failures consumed, success mask `0xf`, 40/40 pings each way | Pass |
| Retry teardown safety | Unload while retries are pending with no post-free work, warning, Oops, or UAF | Unload with 99,980 failures pending; production reload in 857 ms; no kernel fault signature | Pass |
| TX submission/completion errors | Failed submissions release all callback-owned state; completion errors report no false ACK and are observable without blind replay | Source 0.1.5 plus disposable injector and serialized harness are statically verified; live injection has not run | Pending 0.1.5 hardware injection |
| TX teardown safety | Every submitted TX URB is quiesced before skb, mac80211, or driver state is freed | Source 0.1.5 anchors TX URBs and synchronously kills the anchor after draining the producer; pending-TX unbind/unload has not run | Pending 0.1.5 teardown test |
| Physical USB fault attribution | Three valid repetitions for direct USB3, direct USB2, powered USB3, and powered USB2 with topology/power/event logs | Matrix, causal rules, and serialized evidence runner exist; independently powered paths unavailable | Pending hardware |
| Endurance | Bounded unattended run with peer/HWMP state, traffic, checksums, recovery, USB events, temperature, and power flags | Eight-hour DKMS 0.1.2 and bounded 0.1.4 runs passed; a symmetric 0.1.4 eight-hour run is active; 0.1.5 long regression has not run | Pass on prior builds; 0.1.5 endurance pending |
| Upstream hygiene | Reviewable patch split, exact-kernel warning build, strict checkpatch, and comparison with current kernel behavior | Eight downstream patches reproduce production byte-for-byte; a two-patch TX-only series against pinned Linux `315f4bd234b3` reproduces exact final hashes; all TX patches pass v6.12 strict checkpatch 0/0/0; exact-kernel `W=1` for 0.1.5 is pending | Pending current-source build |

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
