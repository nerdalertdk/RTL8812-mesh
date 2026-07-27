# OpenMANET support

## Goal

Support RTL8812AU as a conventional 2.4 GHz 802.11n mesh radio in OpenMANET's
OpenWrt-based 802.11s plus BATMAN-V networking stack.

This is distinct from OpenMANET's primary Morse Micro Wi-Fi HaLow (802.11ah)
radio support. RTL8812AU is not a HaLow device and must have an explicit bearer
profile, UI/configuration behavior, and documented RF/performance expectations.

## Promotion Prerequisites

- Debian 802.11s support passes functional and endurance testing.
- OpenWrt module packaging and static UCI mesh configuration are reproducible.
- RTL8812AU works as a BATMAN-V hard interface on generic OpenWrt.
- A supported OpenMANET Raspberry Pi image/target and release are selected.
- The OpenMANET maintainers' intended role for a non-HaLow mesh bearer is known:
  primary backhaul, optional alternate backhaul, or future bonded link.

## Expected Work

- Add the rtw88 RTL8812AU module and firmware to the OpenMANET image build.
- Add device detection for USB ID `0bda:8812` and any intended rebadged IDs.
- Add an RTL8812AU 2.4 GHz radio/backhaul profile to setup and configuration.
- Configure a fixed permitted channel, HT20 initially, mesh ID, and security.
- Attach the resulting 802.11s mesh-point interface to BATMAN-V.
- Integrate status, neighbor, RSSI, rate, and failure reporting with OpenMANETd
  and the Web UI where appropriate.
- Preserve independent management/recovery access during USB radio failures.
- Validate mesh gate and mesh point roles, local AP/Ethernet client access,
  multicast/mDNS, DHCP behavior, and multi-hop mobility.
- Evaluate multi-radio bonding only after single-bearer operation is reliable.

## Acceptance Criteria

1. A reproducible OpenMANET image boots with the module and firmware included.
2. Setup detects RTL8812AU and offers a clearly labeled 2.4 GHz Wi-Fi profile.
3. Two or more nodes form an 802.11s mesh and use the interface under BATMAN-V.
4. Mesh gate, mesh point, flat LAN, multicast, and failover behavior match the
   applicable OpenMANET networking model.
5. Reboot, hotplug, USB fault recovery, and sustained multi-hop traffic pass.
6. Documentation clearly distinguishes 2.4 GHz 802.11n range/capacity from
   sub-GHz 802.11ah HaLow behavior.

## Risks

- OpenMANET configuration currently centers on Morse Micro HaLow devices and may
  contain radio-specific assumptions outside standard UCI/mac80211 behavior.
- A 2.4 GHz bearer has materially different propagation, congestion, and range.
- The local 2.4 GHz AP and a 2.4 GHz mesh bearer may require concurrency that
  this driver does not initially support, or a separate client-access radio.
- BATMAN-V and OpenMANET behavior can hide lower-layer 802.11s faults; validation
  must retain tests at both layers.
- USB power and reset behavior on Raspberry Pi remains an operational risk.

## References

- <https://openmanet.github.io/docs/>
- <https://openmanet.github.io/docs/networking>
- <https://openmanet.github.io/docs/firmware>

