# Project

## Purpose

Make RTL8812AU native IEEE 802.11s support correct, robust, reproducible on
Debian, and suitable for upstream Linux submission. The active project focus is
standards-correct mesh behavior and evidence-based mesh qualification. Existing
generic USB-lifecycle patches remain separately reviewable; no further generic
transport work is in scope unless a reproduced failure directly prevents mesh
operation.

## Scope

Included:

- RTL8812AU USB and its required RTL8812A/88xxA/shared rtw88 modules;
- mac80211/cfg80211 mesh-point capability and lifecycle behavior;
- open peering, HWMP, unicast, broadcast, multicast, and SAE/AMPE security;
- focused Debian manual/DKMS packaging;
- exact-source static checks and mesh hardware qualification;
- reviewable patches against current Linux wireless development trees.

Excluded:

- unrelated Realtek chipsets and transports;
- new generic USB control, RX, TX, teardown, disconnect, recovery, or
  fault-injection work that is not required by a reproduced mesh failure;
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
- Mesh qualification that distinguishes a mesh-driver failure from an
  environmental or transport observation without expanding the driver scope.
- A minimal, reviewable patch series that applies to the selected upstream
  Linux wireless tree and passes exact-kernel build and strict static checks.
