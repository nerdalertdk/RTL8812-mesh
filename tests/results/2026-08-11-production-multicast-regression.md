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
| `20260811T233505Z` (roles reversed) | 393/400 | 399/400 | 0 | fail |
| `20260811T233906Z` (restored roles; 200-frame counter delta) | 200/200 | 197/200 | 0 | fail |

The retained Pi artifacts are:

- `/var/tmp/rtl8812au-mesh/mesh-multicast-probe/multicast-20260811T214109Z.log`
- `/var/tmp/rtl8812au-mesh/mesh-multicast-probe/multicast-20260811T214345Z.log`
- `/var/tmp/rtl8812au-mesh/mesh-multicast-probe/multicast-20260811T231240Z.log`
- `/var/tmp/rtl8812au-mesh/mesh-multicast-probe/multicast-20260811T233505Z.log`
- `/var/tmp/rtl8812au-mesh/mesh-multicast-probe/multicast-20260811T233906Z.log`

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

## Receiver role reversal

The standard topology puts `fc:22:1c:30:08:c1` (USB path `1-1.2`) in the root
namespace and `fc:22:1c:30:0d:8b` (USB path `1-1.4`) in `meshpeer`. Both PHYs
were moved between namespaces, joined to the same open mesh on channel 1 HT20,
and proven to have bilateral `ESTAB`, reciprocal HWMP paths, and exact DKMS
0.1.5 module provenance. In the reversed topology, `…0d:8b` was root and
`…08:c1` was the peer receiver.

The complete 400-frame run delivered 393/400 from `…0d:8b` to receiver
`…08:c1`, but 399/400 in the reverse direction. This excludes the root
namespace role as the explanation. The loss follows the receiver-specific
physical path comprising adapter `…08:c1`, its antenna/RF path, and USB hub
branch `1-1.2`; it does **not** by itself distinguish among those components.
There were again no qualifying USB transport events. The standard topology was
then restored and passed bilateral mesh/HWMP recovery and exact provenance.

An earlier reversed-role invocation (`20260811T233258Z`) lost sender capture
after round 7 and is invalid; it is deliberately excluded from the result table.
The next discriminating test is a physical USB-port swap while retaining adapter
identities, followed by the same probe.

## Driver-counter check

After standard topology restoration, a ten-round/200-frame probe reproduced
the loss only into `…08:c1` (197/200) without a transport event. The exposed
`rx_dropped` ethtool statistic is not a valid proxy for this loss: over this
interval it rose from 16 to 206 on `…08:c1` and from 1 to 193 on `…0d:8b`.
The near-equal increments are far larger than the three missing receiver
captures, so they must not be used to attribute the multicast failure to a
specific rtw88 receive-drop path.
