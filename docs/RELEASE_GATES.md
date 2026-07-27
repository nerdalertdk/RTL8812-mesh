# RTL8812AU mesh release gates

This matrix defines the evidence required before the Debian driver can be
called robust for native IEEE 802.11s. A passing mixed-adapter result is useful
regression evidence, but cannot substitute for an RTL8812AU-to-RTL8812AU gate.

| Requirement | Required evidence | Current evidence | Status |
| --- | --- | --- | --- |
| Exact-kernel Debian package | All five DKMS modules build, install, load, and match installed `srcversion` values | DKMS 0.1.4 on `6.12.47+rpt-rpi-v8`; all five loaded values match installed artifacts; exact `W=1` and strict checkpatch clean | Pass |
| Open mesh peering | Repeated fresh joins with both peer links `ESTAB` | DKMS 0.1.4 strict 20-cycle churn passed 20/20 | Pass |
| Cold HWMP discovery | Bidirectional first contact after path/neighbour flush and paths at both peers | Strict churn passed 20/20; channel sweep passed channels 1--13 | Pass |
| Open unicast integrity | Checksummed large payload in both directions | DKMS 0.1.4 transferred 512 MiB each direction with matching SHA-256 and no kernel event | Pass |
| Open group traffic | Complete sender capture and at least 99% bidirectional delivery with two stable RTL8812AU radios | Mixed RTL8812AU/RTL8192FU delivered 797/800; 20-cycle strict bursts passed | Pending two RTL8812AU radios |
| SAE/AMPE | Both peers report `COMPLETED` and SAE, then pass bidirectional unicast, multicast, HWMP, and checksummed payload | RTL8812AU started the secure group, used software MGTK fallback, received SAE commits, and removed keys safely; RTL8192FU failed secured-beacon programming before peer discovery | Pending two RTL8812AU radios |
| 2.4 GHz HT20 channels | Fresh peering, cold traffic, and HWMP on every channel allowed by the selected test regulatory profile | Channels 1--13 passed; channel 2 passed 10/10 focused repetitions after an isolated mixed-peer multicast miss | Pass for open mixed-peer regression; repeat production profile with two RTL8812AU radios |
| Transient control `-EPROTO` | Read-only injected fault is consumed by bounded retry; no write injection | Two matching reads, injected failure followed by successful retry, no miss | Pass |
| RX submit recovery | Every RX slot recovers after injected transient failures; traffic remains valid | Eight failures consumed, success mask `0xf`, 40/40 pings each way | Pass |
| Retry teardown safety | Unload while retries are pending with no post-free work, warning, Oops, or UAF | Unload with 99,980 failures pending; production reload in 857 ms; no kernel fault signature | Pass |
| Physical USB fault attribution | Three valid repetitions for direct USB3, direct USB2, powered USB3, and powered USB2 with topology/power/event logs | Matrix, causal rules, and serialized evidence runner exist; independently powered paths unavailable | Pending hardware |
| Endurance | Bounded unattended run with peer/HWMP state, traffic, checksums, recovery, USB events, temperature, and power flags | Eight-hour DKMS 0.1.2 run passed 597 states/1,194 pings/16 transfers; bounded DKMS 0.1.4 run passed 12 states/24 pings/8 transfers; no recovery or USB event; sticky historical power flags recorded | Pass for functional endurance; not clean power-path evidence |
| Upstream hygiene | Reviewable patch split, exact-kernel warning build, strict checkpatch, and comparison with current kernel behavior | `W=1` clean; strict checkpatch 0/0/0; patch order documented | Pass |

## Completion rule

Release readiness requires every row to pass at its stated scope. In
particular, synthetic USB recovery proves driver behavior but cannot establish
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
