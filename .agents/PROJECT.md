# Project

## Purpose

Package native IEEE 802.11s mesh-point support for RTL8812AU as a focused
Debian-compatible out-of-tree rtw88 driver.

## Scope

Included: RTL8812AU USB, RTL8812A/88xxA support, shared rtw88 core, firmware,
DKMS/manual installation, recovery helpers, and hardware-in-loop tests.

Excluded for now: unrelated Realtek chipsets and transports, Android/OpenWrt
packaging, and production claims not backed by completed security/endurance
tests.

## Success criteria

- Reproducible five-module build and DKMS installation on Debian.
- Open and secured 802.11s behavior across supported 2.4 GHz HT20 channels.
- Verified HWMP, multicast, churn, transfer integrity, USB recovery, and
  physical endurance with two stable RTL8812AU peers.
