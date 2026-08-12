# TODO

## Release readiness

- [ ] Run the GitHub release workflow from a test tag or workflow dispatch and
  inspect the generated archives.
- [ ] Publish the first public release after reviewing the generated release
  notes, DKMS source archive, firmware archive, and CI build artifact.

## Deferred work

- [ ] Decide separately whether to pursue independently powered USB-path and
  physical re-enumeration attribution. This is not required for the validated
  mesh release scope.
- [ ] Rebase and submit the upstream patch series under the submitter's real
  identity and Developer Certificate of Origin sign-off.

## Completed

- [x] Qualify DKMS 0.1.6 native 802.11s mesh behavior with two RTL8812AU
  adapters, including secured mesh operation and strict 30-minute endurance.
- [x] Materialize and statically verify downstream, wireless-next, and
  mainline-focused patch series.
