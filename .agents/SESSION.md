# Session

## Current focus

Prepare the repository for a public GitHub release. The production source is
DKMS 0.1.6 and the active native 802.11s mesh qualification gates are closed.

## Current status

- Two RTL8812AU adapters passed open and SAE/AMPE mesh qualification on Debian
  ARM64, including 2.4 GHz HT20/HT40-, non-DFS 5 GHz HT20/HT40+, churn,
  multicast, HWMP, transfer integrity, and a strict 30-minute soak.
- Exact 0.1.6 module provenance, package boundary, static checks, and pinned
  patch-series reproduction pass.
- The generated DKMS source archive was extracted and compiled against the
  exact Raspberry Pi `6.12.47+rpt-rpi-v8` headers, producing all five modules.
- The public release workflow must package source and firmware, build DKMS
  modules against a controlled Debian kernel-header profile, and attach those
  artifacts to version tags.

## Known limitations

- DFS channels are unavailable because radar detection is not exposed through
  nl80211 by this driver.
- Validation is scoped to the recorded adapters, USB topology, host, and
  regulatory profiles. It does not establish physical fault attribution for
  arbitrary hubs, cables, power supplies, or antennas.
- Upstream submission requires a rebase check on the target wireless tree and
  the submitter's real identity plus Developer Certificate of Origin sign-off.

## Next steps

1. Review generated release artifacts from a test tag or workflow dispatch.
2. Publish a signed/tagged GitHub release when ready.
3. Keep generic USB physical-path work separate unless a reproduced mesh issue
   requires it.
