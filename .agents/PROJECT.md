# Project

## Purpose

Package native IEEE 802.11s mesh-point support for RTL8812AU as a focused
Debian-compatible out-of-tree rtw88 driver. The deployment target is an
off-grid MANET carried by mobile nodes, with an engineering target of roughly
1 km line of sight at 2.4 GHz using 2x2 MIMO-capable radios.

## Scope

Included: RTL8812AU USB, RTL8812A/88xxA support, shared rtw88 core, firmware,
DKMS/manual installation, recovery helpers, and hardware-in-loop tests.

Excluded for now: unrelated Realtek chipsets and transports, Android/OpenWrt
packaging, and production claims not backed by completed security/endurance
tests.

## RF and deployment constraints

- HT20 is the range/interference baseline; wider channels are not required for
  the first production profile.
- USB2 is the intended transport profile for 2.4 GHz deployment, pending the
  physical USB2 release gates:
  `rtw_usb.switch_usb_mode=N` prevents the adapter from switching to USB3 and
  reduces local USB3 interference risk. USB3 remains a separately validated
  regression profile, not the default RF deployment choice.
- Range is a bidirectional link property. High conducted transmit power on one
  node cannot compensate for a weaker return path, obstructed Fresnel zone, or
  poor receive antenna placement.
- Deployment is multinational. Country code, allowed channels, EIRP/PSD limit,
  antenna gain, cable loss, and any indoor/outdoor restrictions belong to a
  per-country deployment profile rather than a Denmark-specific assumption.
- The driver must retain cfg80211/mac80211 regulatory enforcement. It must not
  provide a mechanism for bypassing the active regulatory database.
- Advertised 1 W / 30 dBm adapters are useful hardware candidates, not an
  authorization to radiate 30 dBm EIRP. Effective power must be calculated and
  validated for the country and complete antenna assembly.
- Mobile-node power delivery, thermal behavior, USB stability, antenna spacing,
  body/vehicle shadowing, and installation height are part of the RF system.

## Success criteria

- Reproducible five-module build and DKMS installation on Debian.
- Open and secured 802.11s behavior across supported 2.4 GHz HT20 channels.
- Verified HWMP, multicast, churn, transfer integrity, USB recovery, and
  physical endurance with two stable RTL8812AU peers.
- A repeatable 100 m--1 km LOS field test characterizes both directions across
  node height/orientation cases and records RSSI, rate, retries, loss, latency,
  throughput, peer state, HWMP state, power, and temperature.
