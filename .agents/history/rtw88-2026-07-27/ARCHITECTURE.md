# ARCHITECTURE.md

## Overview

The project extends the Linux mac80211-facing `rtw88` driver so an RTL8812AU
USB device can participate as an IEEE 802.11s mesh point. mac80211 owns mesh
protocol behavior; the driver must correctly expose capabilities and program
the RTL8812A MAC, firmware, USB transport, peers, beacons, and receive filters.
The resulting mesh-point interface is the radio bearer. Native 802.11s HWMP can
provide path selection directly; alternatively, `batman-adv` can use the mesh
interface as a hard interface for the project's higher-level MANET behavior.

## Components

- cfg80211/nl80211: userspace configuration and capability reporting.
- mac80211: mesh peering, path selection, frame construction, and station state.
- rtw88 core (`main.c`, MAC/TX/RX/firmware code): interface and peer lifecycle,
  beacon handling, filtering, rate control, security, and power management.
- RTL8812A support: chip-specific PHY/MAC operations and firmware integration.
- rtw USB: device probe and bulk transfer transport.
- Test control plane: `iw` initially, then `wpa_supplicant` for secured mesh.
- MANET layer: native 802.11s HWMP for driver isolation and baseline tests;
  optional `batman-adv`/BATMAN-V for deployment-level mobility and forwarding.

## Data Flow

Configuration flows from userspace through nl80211, cfg80211, and mac80211 into
rtw88 callbacks. mac80211 supplies mesh management and data frames to rtw88,
which creates hardware descriptors and sends them over USB. Received USB frames
are decoded by rtw88 and delivered to mac80211 for mesh processing and Linux
network-stack delivery.

For BATMAN deployments, `batman-adv` consumes the mesh-point netdevice as a hard
interface and exposes `bat0` to the IP/bridge layer. Keeping this optional lets
driver failures be distinguished from MANET routing or bridge behavior.

## Integrations

- Linux kernel headers/build system and mac80211/cfg80211 APIs.
- RTL8812A firmware (`rtw88/rtw8812a_fw.bin`).
- A headless Debian Raspberry Pi hardware-in-loop target with native USB
  ownership and SSH management independent of the test radio.
- At least one independently working 802.11s peer.

## Operational Considerations

- Build/source work can run on the macOS development host.
- Module loading, USB reset, RF tests, logs, and captures run on the Raspberry Pi.
- Maintain an alternate management path during driver tests.
- Preserve crash logs and exact kernel/firmware/build identifiers per test.
- Start with one open, fixed-channel 2.4 GHz HT20 mesh interface and power saving
  disabled.
- Advertise RTL8812AU USB mesh in `interface_modes`, but omit mesh from the
  existing station/AP concurrency combination. cfg80211 treats standalone
  interface types separately and rejects one-interface combination records.
- Add security, VHT, DFS, concurrency, and endurance tests incrementally.
