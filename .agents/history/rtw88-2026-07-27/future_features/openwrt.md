# OpenWrt support

## Goal

Make the Debian-proven RTL8812AU 802.11s implementation usable and maintainable
on supported OpenWrt targets.

## Promotion Prerequisites

- Open 2.4 GHz HT20 mesh is stable on Debian.
- Peer lifecycle, forwarding, multicast, and recovery tests pass.
- The driver patch shape and intended upstream destination are understood.
- At least one concrete OpenWrt target, release, architecture, and kernel ABI
  have been selected.

## Expected Work

- Add or adapt an OpenWrt kernel-module package for this `rtw88` driver and its
  RTL8812A firmware.
- Rebase against the OpenWrt target kernel and mac80211/backports APIs.
- Ensure `CONFIG_MAC80211_MESH` and required cfg80211/mac80211 options are built.
- Confirm `iw list` advertises `mesh point` for the device.
- Validate UCI `mode 'mesh'` configuration with a fixed 2.4 GHz HT20 channel.
- Validate both open mesh and SAE using a mesh-capable `wpad` package.
- Test service restart, reboot, hotplug, sysupgrade persistence, and USB recovery.
- Evaluate `mesh11sd` only after static UCI configuration is reliable.
- Document image size, dependency, regulatory, and USB power constraints.

## Acceptance Criteria

1. A reproducible OpenWrt image/package build includes the module and firmware.
2. The adapter probes after cold boot and hotplug and exposes `mesh point`.
3. Static UCI configuration establishes the same tested mesh as Debian.
4. Open and SAE peering, forwarding, and recovery pass on the selected target.
5. Installation, configuration, upgrades, and known limitations are documented.

## Risks

- OpenWrt kernel/mac80211 backports may differ from the Debian build APIs.
- Many routers have limited flash, RAM, USB power, or only USB 2.0 ports.
- Replacing `wpad-basic-*` with a mesh-capable variant affects image size.
- Bridging multiple backhauls can form Layer-2 loops; this is deployment behavior,
  not a driver feature, and needs explicit topology controls.
- Carrying an out-of-tree kernel module across OpenWrt upgrades is maintenance
  intensive unless the driver changes are accepted upstream.

## References

- <https://openwrt.org/docs/guide-user/network/wifi/mesh/802-11s>
- <https://openwrt.org/docs/guide-user/network/wifi/mesh/mesh11sd>

