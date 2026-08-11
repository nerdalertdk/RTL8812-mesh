# Project

## Purpose

Make RTL8812AU native IEEE 802.11s support correct, robust, reproducible on
Debian, and suitable for upstream Linux submission. This includes
standards-correct mesh behavior, USB transport fault handling, teardown safety,
and evidence-based qualification.

## Scope

Included:

- RTL8812AU USB and its required RTL8812A/88xxA/shared rtw88 modules;
- mac80211/cfg80211 mesh-point capability and lifecycle behavior;
- open peering, HWMP, unicast, broadcast, multicast, and SAE/AMPE security;
- USB control, RX, TX, teardown, disconnect, and recovery behavior;
- focused Debian manual/DKMS packaging;
- exact-source static checks, fault injection, and hardware qualification;
- reviewable patches against current Linux wireless development trees.

Excluded:

- unrelated Realtek chipsets and transports;
- application topology or routing layers above native IEEE 802.11s;
- product, range, antenna, enclosure, field-use, and other use-case planning;
- downstream operating-system or appliance integration not required to prove
  the driver itself.

## Constraints

- Preserve cfg80211/mac80211 regulatory enforcement.
- Build and validate against the exact target kernel before loading modules.
- Preserve the five-module package boundary: `rtw_core`, `rtw_usb`,
  `rtw_88xxa`, `rtw_8812a`, and `rtw_8812au`.
- Separate synthetic driver-fault evidence from physical USB power, cable,
  adapter, hub, and host-controller evidence.
- Do not claim conformance or robustness beyond the scope of completed gates.

## Success criteria

- Reproducible exact-kernel Debian build, install, load, and provenance.
- Stable standalone mesh-point creation, deletion, peering, and churn.
- Correct bidirectional HWMP discovery and repair.
- Correct unicast, broadcast, and multicast behavior.
- Correct SAE/AMPE operation using mac80211 software crypto where required.
- Correct TX/RX ownership and bounded behavior across USB failures and teardown.
- Bounded driver teardown and reprobe behavior after physical USB
  re-enumeration; userspace reconstruction remains test infrastructure rather
  than part of the upstream driver deliverable.
- Endurance and physical-path evidence sufficient to distinguish driver faults
  from external USB faults.
- A minimal, reviewable patch series that applies to the selected upstream
  Linux wireless tree and passes exact-kernel build and strict static checks.
