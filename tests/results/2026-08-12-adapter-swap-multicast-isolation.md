# Physical adapter-swap multicast isolation

## Method

The two RTL8812AU adapters were physically exchanged between the same Pi USB
hub branches.  The test resolves interfaces by permanent MAC, then reconstructs
the same open 2.4 GHz HT20 mesh with exact loaded DKMS 0.1.6 provenance.

Before the swap:

- `fc:22:1c:30:08:c1` was on `1-1.4`.
- `fc:22:1c:30:0d:8b` was on `1-1.1`.

After the swap:

- `fc:22:1c:30:08:c1` was on `1-1.1`.
- `fc:22:1c:30:0d:8b` was on `1-1.4`.

Both peers re-established `ESTAB`, used channel 1 HT20 at 20 dBm, and had
reciprocal HWMP paths.  The probe used independent sender and receiver capture
for 400 group frames in each direction.

## Result

| Topology | `…08:c1` sender result | `…0d:8b` sender result | Fresh transport events |
| --- | --- | --- | --- |
| Before: `…08:c1` on `1-1.4` | 391/400, then 394/400 | 400/400, then 400/400 | 0 |
| After: `…08:c1` on `1-1.1` | 333/400 | 395/400 | 0 |

The physical swap itself produced a short burst of recoverable RX `-71` events
on `1-1.4`; those are transition evidence and predate the post-swap probe.
The post-swap probe's own kernel interval was clean.

## Conclusion

The severe group-frame loss follows the `fc:22:1c:30:08:c1` physical unit or
an antenna physically attached to it, not either tested USB branch. The test
does not distinguish the adapter from its attached antenna, and it does not
prove a driver defect. A detached-antenna exchange or a known-good third
RTL8812AU is required to separate those two hardware causes.
