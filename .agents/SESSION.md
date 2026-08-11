# Session

## Current focus

Make RTL8812AU native IEEE 802.11s support correct, robust, reproducible on
Debian, and suitable for upstream Linux submission. The immediate work is to
qualify source DKMS 0.1.5 with deterministic USB TX error/teardown evidence,
then repeat the IEEE 802.11s behavioral and endurance gates with two RTL8812AU
peers.

## Current source

- Production source fixes standalone RTL8812AU USB mesh admission, mesh group
  queue selection, mesh software crypto, USB control serialization/retry, RX
  capacity recovery, TX ownership/error reporting, and TX URB teardown.
- The package boundary is exactly `rtw_core`, `rtw_usb`, `rtw_88xxa`,
  `rtw_8812a`, and `rtw_8812au`.
- Downstream eight-patch and pinned wireless-next eight-patch series reproduce
  the validated four-file final source exactly.
- A separate pinned current-mainline TX-only series captures only TX changes
  not already present in its target tree.
- Repository static checks and stored production patches pass strict validation.

## Behavioral evidence

- Two RTL8812AU peers established open bilateral `ESTAB` links and reciprocal
  HWMP paths across channels 1--13 HT20.
- Strict 20-cycle churn, bidirectional cold first contact, and checksummed
  512 MiB transfers passed on DKMS 0.1.4.
- Sender-captured multicast delivered 399/400 and 400/400 frames with no USB
  event; the separate churn reachability gate passed 20/20.
- SAE/AMPE passed peer-specific SAE acceptance, decrypted AMPE, authorization,
  MFP, bidirectional unicast/multicast, reciprocal HWMP, and checksummed payloads
  with two RTL8812AU peers.
- Prior source versions passed bounded and eight-hour endurance. Current-source
  0.1.5 behavioral regression remains required after TX changes.

## USB evidence

- Read-only injected control `-EPROTO` exercised bounded retry and recovery.
- Eight injected RX completion/submit failures exceeded the four-URB pool and
  recovered all slots without losing the peer.
- RX teardown with retry work pending completed without warning, Oops, UAF, or
  post-free work evidence.
- Version-pinned udev/systemd test infrastructure reconstructed both mesh
  interfaces, addressing, peering, traffic, and HWMP after controlled rebind;
  it is not part of the proposed upstream driver patches.
- A previous simultaneous physical disconnect involved both USB radios and
  shared-path power/topology evidence. It is not evidence of an isolated
  RTL8812AU mesh failure; the controlled physical USB matrix remains open.

## Source 0.1.5 pending evidence

- Exact-kernel `W=1` build, DKMS install, and five-module loaded provenance.
- Deterministic generic TX submission rejection, populated aggregate rejection
  with post-cleanup proof, and completion `-EPROTO` with no-false-ACK proof.
- Unbind while a selected TX callback is active, requiring zero anchored URBs
  and callbacks after synchronous kill and no lifetime fault signature.
- Production reload followed by open churn, multicast, HWMP, SAE/AMPE,
  checksummed transfer, and endurance regression.
- Direct and independently powered USB2/USB3 physical-path repetitions.

## Test policy

- Serialize every mutating hardware test with
  `/run/lock/rtw88-mesh-test.lock`.
- Resolve radios by permanent MAC rather than unstable netdev names.
- Require exact installed/loaded module provenance before topology mutation.
- Treat exit 0 as a clean functional and kernel interval, exit 4 as requiring
  transport-event review, and provenance/environment failures as invalid
  evidence rather than driver failures.
- Keep synthetic fault evidence distinct from cable, power, hub, adapter, and
  host-controller evidence.
