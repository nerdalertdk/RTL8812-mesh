# Eight-hour two-RTL8812AU soak — 2026-08-06/07

## Result

The DKMS 0.1.4 functional soak ran from `2026-08-06T18:34:21Z` through
`2026-08-07T02:34:55Z` and completed its requested 28,800 seconds before a
later user-reported manual Raspberry Pi power removal.

- established/HWMP states: 597/597;
- successful directional ping batches: 1,194/1,194;
- checksummed 10 MiB transfers: 16/16;
- unavailable states, failed pings/transfers, recovery windows, and
  invalidations: zero;
- kernel transport/power events during the measured interval: zero;
- temperature: 74.497--79.367 C;
- final power mask: `0x80000`, the historical soft-temperature-limit bit, with
  no undervoltage bit recorded.

This is clean functional endurance evidence for DKMS 0.1.4. The historical
thermal bit prevents treating it as a thermally pristine physical USB-path
matrix repetition.

## Post-soak chain defect

The final 512 MiB transfer and build-only DKMS 0.1.5 job did not run. The soak
created `summary-20260806T183421Z.log`, while
`pi_mesh_soak_finalize.sh` searched for
`soak-20260806T183421Z-summary.log` and exited before starting the transfer.
The queued build consequently had no successful finalizer/transfer evidence.

This was a deterministic test-harness filename mismatch, not a driver,
workload, USB, or power failure. The finalizer now uses the producer's exact
`summary-$SOAK_RUN_ID.log` convention, and
`scripts/check-soak-finalizer-contract.sh` executes an offline matching-summary
fixture through the final transfer handoff.

## Power-removal boundary

The later manual power removal occurred days after the soak summary closed and
cannot invalidate the completed eight-hour interval. No monitored workload
continued after the soak, so the intervening powered-on days are not additional
endurance evidence.

## Reboot and deferred final transfer

After power was restored on 2026-08-11, exact DKMS 0.1.4 five-module
provenance passed and the standard userspace test infrastructure recreated two
mesh-point interfaces. Both peers reported `ESTAB`, reciprocal HWMP paths, and
5/5 bidirectional ping replies. Current power state was clean at
`get_throttled=0x0`.

The repository-exact transfer harness
(`418112c1bad80b1f93bcaa4fa44c071b598d3f3f648a932ebe05119c5b6b4675`)
then completed the deferred integrity gate:

- source: 536,870,912 bytes, SHA-256
  `465eaefa2d3cb399e5439d7d17e1a73599640b3a1fc3933119f7bd3afba9968b`;
- root to peer: 4,424,214 B/s, matching SHA-256;
- peer to root: 4,716,183 B/s, matching SHA-256;
- reciprocal postflight HWMP paths: one at each peer;
- kernel transport/power events during the 254-second interval: zero.

This closes the final integrity evidence for the 0.1.4 extended run. It does
not qualify source 0.1.5, which still requires an exact-current source stage,
build, install, and regression.
