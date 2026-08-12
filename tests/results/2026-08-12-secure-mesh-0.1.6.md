# Secured two-RTL8812AU mesh — 2026-08-12

## Scope

Exact DKMS 0.1.6 RTL8812AU peers ran the SAE/AMPE mesh gate on the validated
2.4 GHz channel-1 HT20 profile. The harness required peer-specific SAE
acceptance and decrypted AMPE on both nodes, completed authorization/MFP,
bidirectional traffic and multicast, reciprocal HWMP, a 32 MiB checksummed
transfer in each direction, and provenance-checked restoration of the open
mesh afterward.

## Result

- Both peers reached `wpa_state=COMPLETED`, `authorized=yes`,
  `authenticated=yes`, and `MFP=yes`.
- Both wpa_supplicant logs showed SAE accepted for the specific peer and a
  decrypted AMPE element.
- Both 20-packet directional ping runs passed; binary multicast and reciprocal
  HWMP passed.
- Checksummed 32 MiB transfers passed root-to-peer at 5,543,196 B/s and
  peer-to-root at 7,704,726 B/s, with matching SHA-256 and postflight HWMP.
- The secured interval contained zero classified transport events.
- Cleanup recovered the open channel-1 HT20 mesh with exact five-module 0.1.6
  provenance and reciprocal HWMP.

## Harness correction

An initial valid security workload run exposed that the recovery helper was
called without its required exact-version environment and its failure could be
ignored. `pi_secure_mesh.sh` now requires `EXPECTED_VERSION`, passes it to the
helper, and fails the gate if the provenance-checked open topology cannot be
restored. The result above is the successful rerun using that corrected path.
