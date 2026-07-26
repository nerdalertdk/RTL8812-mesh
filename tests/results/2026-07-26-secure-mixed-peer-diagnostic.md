# Mixed-peer secured mesh diagnostic — 2026-07-26

## Scope

This result diagnoses an earlier SAE/AMPE attempt between the production
RTL8812AU rtw88 driver and the experimental RTL8192FU `rtl8xxxu` fixture. It is
not an RTL8812AU-to-RTL8812AU security pass.

## RTL8812AU observations

- wpa_supplicant selected mesh-point mode and started the secured mesh group.
- It initialized the mesh group state machine and generated its transmit MGTK.
- The nl80211 MGTK installation completed through mac80211's software-crypto
  fallback; the driver intentionally rejects mesh hardware `SET_KEY`.
- The RTL8812AU repeatedly received peer SAE commits as authentication
  management frame, showing that the mesh RX filter admitted those frames.
- Each commit was dropped by wpa_supplicant with `Mesh peer ... not yet known`,
  before SAE cryptographic processing, because no valid peer mesh beacon had
  established the discovery entry.
- Defensive key removals were issued during teardown without a driver failure,
  exercising the corrected `DISABLE_KEY` contract.

## RTL8192FU observations

- Its supplicant started a mesh group but nl80211 reported
  `Beacon set failed: -95 (Operation not supported)` while configuring the
  secured beacon.
- It repeatedly transmitted SAE commits but never received a response because
  the RTL8812AU had no discovered mesh peer to authenticate.
- The peer eventually reported repeated `MESH-SAE-AUTH-FAILURE`, then
  `MESH-SAE-AUTH-BLOCKED`.
- Teardown also produced `Driver failed to set ...: -22`, an nl80211 frame
  command `-22`, and a failed peering-frame transmission.

## Attribution and gate status

The first causal failure is the experimental peer's unsupported secured-beacon
operation. The logs do not show RTL8812AU SAE or AMPE rejecting a known peer.
They provide useful positive evidence for RTL8812AU secured-mesh admission,
software group-key fallback, management RX, and safe key removal, but cannot
prove SAE completion, pairwise/MGTK payload encryption, secured multicast, or
interoperability. Those gates still require a second stable RTL8812AU.

The Pi onboard `brcmfmac` radio was also inspected as an alternative peer. Its
current firmware/driver advertises IBSS, managed, AP, and P2P modes, but not
`NL80211_IFTYPE_MESH_POINT`, so it cannot replace the missing release peer.
