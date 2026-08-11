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
