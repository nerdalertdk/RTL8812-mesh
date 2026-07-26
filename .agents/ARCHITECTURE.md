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

## Test topology

The current Pi harness resolves radios by permanent MAC and places the peer in
the `meshpeer` network namespace. Recovery is handled by udev/systemd tooling in
`tests/`.
