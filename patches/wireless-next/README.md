# Full wireless-next series

This directory pins the four affected rtw88 files from wireless-next commit
`ca800a9302764c445de0da0e84d2252400a770ee`, inspected on 2026-08-06, and an
eight-patch rebase of the complete production delta.

The rebase intentionally differs from the downstream series where current
wireless-next has changed:

- its existing independent `FIF_OTHER_BSS` handling is retained;
- its RTL8822C-only interface combinations are not changed;
- the RX delayed-work initializer uses current-tree context;
- reserved-page and H2C synchronous submission cleanup already upstream is
  not duplicated;
- TX ownership/error handling is applied after the control and RX changes.

Run `scripts/check-wireless-next-series.sh` to verify all four baseline hashes,
coherent `1/8` through `8/8` mail metadata, strict patch application, and all
four final hashes. All generated patches pass Linux v6.12
`checkpatch.pl --strict --no-tree --no-signoff` with zero errors, warnings, or
checks. The neutral identity and omitted sign-off are intentional repository
privacy measures; regenerate the final mail identity and add a valid DCO
sign-off before submission.

This is an offline source/applicability artifact. Build and hardware evidence
must be repeated against the exact eventual submission head.
