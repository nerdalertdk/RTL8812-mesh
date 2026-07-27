# PROJECT.md

## Purpose

Build a reliable 2.4 GHz MANET using RTL8812AU radios operating as IEEE 802.11s
mesh points. The core deliverable is mesh-point support in this mac80211-based
`rtw88` driver; Debian, Android, OpenWrt, and OpenMANET are deployment targets.

## Scope

Current milestone:

- RTL8812AU USB operation with a single 802.11s mesh interface.
- Debian-first support on a headless Raspberry Pi test target.
- 2.4 GHz operation, initially on a fixed permitted channel at HT20.
- Open-mesh bring-up, peer establishment, forwarding, and stability.
- Native mac80211 802.11s operation only; no external MANET overlay is required
  to prove the driver.
- Mesh-specific mac80211 integration, station handling, beaconing, filtering,
  rate control, and power-management fixes.
- HT/VHT and secured mesh validation after basic operation is reliable.
- Changes suitable for broader `rtw88` use when supported by evidence.

Initially out of scope:

- macOS driver support.
- Android integration until the Debian implementation is validated.
- OpenWrt packaging and integration until the Debian implementation is validated;
  see `.agents/future_features/openwrt.md`.
- OpenMANET integration until Debian and generic OpenWrt support are validated;
  see `.agents/future_features/openmanet.md`.
- `batman-adv`, MANET topology design, and application-layer integration.
- Mesh plus AP/station concurrency.
- Production claims before multi-node and endurance testing.

## Technology Stack

- C and Linux kernel module APIs.
- Linux mac80211/cfg80211/nl80211.
- `rtw88`, RTL8812A firmware, and USB transport.
- Kernel build tooling, DKMS where appropriate, `iw`, `wpa_supplicant`,
  debugfs, trace/log capture, and packet capture.

## Constraints

- The development host is an Apple Silicon Mac running macOS 26.5; it can edit
  and cross-build source but cannot load this Linux driver.
- Runtime tests use a headless Raspberry Pi running Debian with direct ownership
  of the USB device and SSH management over a separate interface.
- The attached adapter identifies as Realtek `0bda:8812` and currently connects
  at USB 2.0 high speed (480 Mbit/s).
- A second, known-good 802.11s node is required for peering validation.
- Radio operation must follow the Linux regulatory domain and local rules.
- All mesh peers operate on one common channel at a time. The eventual solution
  should allow selection among all locally permitted 2.4 GHz channels; initial
  testing uses one non-DFS HT20 channel.
- Driver/firmware limitations are unknown until mesh-mode experiments run.

## Success Criteria

1. Linux advertises mesh-point mode for the RTL8812AU PHY.
2. A mesh interface can be created and removed repeatedly without faults.
3. The adapter establishes and retains peering with a known-good mesh node.
4. Unicast, multicast, path discovery, and forwarding operate correctly.
5. Peer churn, module reload, and sustained traffic do not hang the device.
6. Supported security and HT/VHT behavior are documented with test evidence.
7. The Debian result provides a defined path to later Android integration.
8. The mesh-point bearer works without an external MANET overlay.
9. USB `-EPROTO` (`-71`) has a reproducible cause: any driver fault is fixed,
   or an external power/hub fault is conclusively isolated and documented.
10. USB disconnect/re-enumeration either reconstructs the mesh automatically or
    produces a bounded, observable failure with a reliable recovery procedure.
