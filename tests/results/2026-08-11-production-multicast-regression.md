# Production DKMS 0.1.5 multicast regression — 2026-08-11

## Result

The quantitative production multicast gate did not meet its 99% release
threshold in either of two 400-frame bidirectional runs. Exact five-module
DKMS 0.1.5 provenance, bilateral mesh peering, and the preceding strict
20-cycle churn/HWMP gate were clean.

| Run | Root → peer | Peer → root | Kernel transport events | Verdict |
| --- | ---: | ---: | ---: | --- |
| `20260811T214109Z` | 400/400 | 393/400 | 0 | fail |
| `20260811T214345Z` | 398/400 | 390/400 | 0 | fail |
| `20260811T231240Z` (10 dBm control) | 400/400 | 394/400 | 0 | fail |

The retained Pi artifacts are:

- `/var/tmp/rtl8812au-mesh/mesh-multicast-probe/multicast-20260811T214109Z.log`
- `/var/tmp/rtl8812au-mesh/mesh-multicast-probe/multicast-20260811T214345Z.log`
- `/var/tmp/rtl8812au-mesh/mesh-multicast-probe/multicast-20260811T231240Z.log`

Both adapters were on channel 1 HT20 with a strong direct link (roughly
−10 dBm). Firmware reported a historical thermal/throttle mask, but no current
throttle bit and the temperature fell to 73 C during review. Neither interval
contained USB reset, disconnect, `-EPROTO`, or other transport signature.

## Interpretation

This is reproducible sender-confirmed multicast loss after the sender network
stack, predominantly from the namespace peer toward the root. It is a
functional regression candidate or a test-topology RF/coexistence limitation;
the current evidence does not identify which. It must not be attributed to
USB transport and prevents source 0.1.5 from closing its multicast qualification
gate until isolated and corrected or otherwise explained by controlled evidence.

## Reduced-power control

The third run temporarily set both adapters to 10 dBm, then restored the
normal automatic policy (reported as 20 dBm on both radios). It delivered
400/400 root-to-peer and 394/400 peer-to-root frames with zero kernel transport
events. Reducing near-field power was therefore not sufficient to explain or
eliminate the directional loss. The next isolation is to reverse which physical
adapter receives in the root namespace while retaining the same mesh workload.
