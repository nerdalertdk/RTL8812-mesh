# Architecture

## Module stack

`rtw_8812au` -> `rtw_8812a` -> `rtw_88xxa` -> `rtw_usb` + `rtw_core`

The package builds only those five modules. `rtw_core` contains mac80211,
firmware, PHY/MAC, security, power-management, regulatory, TX, and RX support.

## Installation

- Manual modules: `/lib/modules/<kernel>/updates/rtl8812au-mesh/`
- DKMS modules on Debian: `/lib/modules/<kernel>/updates/dkms/`
- Firmware: `/lib/firmware/rtw88/rtw8812a_fw.bin`

The package does not overwrite distribution module files in `kernel/`.
It does replace the effective `rtw_core` and `rtw_usb` selected by depmod, so an
unrelated downstream `rtw_*` chipset module from another source revision is an
ABI conflict even though its file remains under `kernel/`.

## Test topology

The current Pi harness resolves radios by permanent MAC and places the peer in
the `meshpeer` network namespace. Recovery is handled by udev/systemd tooling in
`tests/`. Recovery is version-pinned: its environment must set
`EXPECTED_VERSION`, and the helper runs the exact five-module DKMS provenance
gate under the hardware lock before changing mesh topology.

For the intended 2.4 GHz deployment profile, load `rtw_usb` with
`switch_usb_mode=N`; this keeps RTL8812AU at USB2 and avoids its intentional
USB2-to-USB3 re-enumeration. This profile remains pending physical USB2 release
gates. The USB3 topology is retained for required regression and physical-path
testing.
