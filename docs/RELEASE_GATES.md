# RTL8812AU mesh release gates

This matrix defines the evidence required before the Debian driver can be
called robust for native IEEE 802.11s. A passing mixed-adapter result is useful
regression evidence, but cannot substitute for an RTL8812AU-to-RTL8812AU gate.

| Requirement | Required evidence | Current evidence | Status |
| --- | --- | --- | --- |
| Exact-kernel Debian package | All five DKMS modules build, install, load from `updates/dkms`, match kernel vermagic and installed `srcversion`, and have recorded hashes with no unrelated shared-core consumer | DKMS 0.1.6 passed exact `W=1` and DKMS build-only gates, then installed and loaded on `6.12.47+rpt-rpi-v8`; five-module provenance, hashes, and `srcversion` fields matched exactly | Pass for 0.1.6 package |
| Open mesh peering | Repeated fresh joins with both peer links `ESTAB` | DKMS 0.1.5 strict retained 20-cycle repeat passed 20/20 with bilateral mesh peering on `1-1.1`/`1-1.4` | Pass for validated topology |
| Mesh teardown lifecycle | Mesh leave, confirmed station-table quiescence, netdev down/up, rejoin, directional cold traffic, multicast, and HWMP without kernel warning or USB transport event | Exact DKMS 0.1.6 passed 20/20 serialized cycles in 169 s; peering ranged 117--133 ms and all traffic/HWMP checks passed with a clean scoped kernel interval | Pass for HT20 validated topology |
| Cold HWMP discovery | Bidirectional first contact after path/neighbour flush and paths at both peers | DKMS 0.1.5 strict retained 20-cycle repeat passed 20/20 bidirectional first contact and reciprocal HWMP paths; its channel sweep remains pending | Pass for HT20 validated topology; channel sweep pending |
| Open unicast integrity | Checksummed large payload in both directions | DKMS 0.1.5 transferred 512 MiB each direction with matching SHA-256 at 5.23 and 6.86 MB/s, reciprocal postflight HWMP, and zero kernel transport event on `1-1.1`/`1-1.4` | Pass for validated topology |
| Open group traffic | Complete sender capture and at least 99% bidirectional delivery with two stable RTL8812AU radios | Channel-1 loss follows neither USB branch, but the same `…08:c1` adapter/antenna/workload delivers 400/400 both directions on 5 GHz channel 149 and 399/400 / 400/400 on 2.4 GHz channel 13, all with zero transport event | Pass on controlled 5 GHz and 2.4 GHz channel-13 profiles; channel-1 environment excluded from driver attribution |
| SAE/AMPE | Both peers prove completed SAE and decrypted AMPE, then pass bidirectional unicast, multicast, HWMP, and checksummed payload | Exact DKMS 0.1.6 passed peer-specific SAE acceptance/decrypted AMPE, MFP/authorization, bidirectional unicast/multicast/HWMP, 32 MiB checksummed transfer in both directions, zero transport events, and provenance-checked open-mesh restoration | Pass for secured HT20 validated topology |
| 2.4 GHz HT20 channels | Fresh peering, cold traffic, multicast reachability, and HWMP on every channel allowed by the selected test regulatory profile | Exact DKMS 0.1.6 serialized sweep passed channels 1--13, 13/13, with bilateral peering, cold traffic, multicast reachability, HWMP, and clean scoped kernel interval | Pass for DK channels 1--13 HT20 |
| 2.4 GHz HT40 compatibility | Where regulatory domain, channel pairing, and coexistence rules permit it: open peering, HWMP, sender-captured multicast, SAE/AMPE, transfer, and short churn with two RTL8812AU peers | Exact 0.1.6 smoke passed open bilateral peering/HWMP and one serialized lifecycle cycle on legal channel-13 HT40− with a clean kernel interval; quantitative multicast, security, transfer, and multi-cycle coverage remain | Smoke pass; full gate pending |
| 5 GHz HT20 compatibility | Open peering, HWMP, sender-captured multicast, SAE/AMPE, transfer, and short churn on permitted 5 GHz channels with two RTL8812AU peers | Exact 0.1.6 passed open bilateral peering/HWMP, one serialized churn cycle, and quantitative sender-captured multicast 400/400 in both directions on non-DFS channel 149 at the DK-enforced 13 dBm limit, with clean kernel intervals; security, transfer, and multi-cycle coverage remain | Partial pass; full gate pending |
| 5 GHz HT40 compatibility | Same as 5 GHz HT20 at 40 MHz where permitted, including DFS handling when the selected channel requires it | Exact 0.1.6 passed open bilateral peering/HWMP, one serialized churn cycle, and quantitative sender-captured multicast 400/400 in both directions on the non-DFS channel-149/153 HT40+ block at the DK-enforced 13 dBm limit, with clean kernel intervals; security, transfer, multi-cycle, and DFS coverage remain | Partial pass; full gate pending |
| Transient control `-EPROTO` | Read-only injected fault is consumed by bounded retry; no write injection | Two matching reads, injected failure followed by successful retry, no miss | Pass |
| RX submit recovery | Every RX slot recovers after injected transient failures; traffic remains valid | Eight failures consumed, success mask `0xf`, 40/40 pings each way | Pass |
| Retry teardown safety | Unload while retries are pending with no post-free work, warning, Oops, or UAF | Unload with 99,980 failures pending; production reload in 857 ms; no kernel fault signature | Pass |
| TX submission/completion errors | Driver-owned aggregate buffers never enter mac80211 status/purge paths; failed submissions release all callback-owned state; completion errors report no false ACK and are observable without blind replay | Disposable 0.1.5 injection passed pre-submit rejection, populated aggregate rejection with post-cleanup proof, and completion `-EPROTO` with the post-status exact-count marker | Pass (disposable fault gate) |
| TX teardown safety | Every submitted TX URB is quiesced before skb, mac80211, or driver state is freed | Disposable selected-device test proved USB core serializes remove after an active completion; post-kill anchor and callback counts were zero and rebind was bounded, with no lifetime fault signature | Pass (disposable teardown gate) |
| Physical USB fault attribution | Three valid repetitions for direct USB3, direct USB2, powered USB3, and powered USB2 with topology/power/event logs | Matrix, causal rules, and serialized evidence runner exist; independently powered paths unavailable | Pending hardware |
| Endurance | Bounded unattended run with peer/HWMP state, traffic, checksums, recovery, USB events, temperature, and power flags | DKMS 0.1.5 bounded 30-minute soak completed 37/37 states, 74/74 ping batches, and 6/6 checksum-verified transfers with zero recovery, invalidation, transport event, or throttling on `1-1.1`/`1-1.4`; the earlier 0.1.4 eight-hour result remains historical evidence | Pass for 0.1.5 bounded validated topology; long-duration and 0.1.6 pending |
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
