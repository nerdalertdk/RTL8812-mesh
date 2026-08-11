# Architecture

## Module stack

`rtw_8812au` -> `rtw_8812a` -> `rtw_88xxa` -> `rtw_usb` + `rtw_core`

The package builds only those five modules. `rtw_core` contains mac80211,
firmware, PHY/MAC, security, power-management, regulatory, TX, and RX support.

## IEEE 802.11s ownership

mac80211 owns mesh peering, frame construction, HWMP, and software crypto. The
driver advertises a standalone mesh-point interface only for RTL8812AU USB and
must correctly implement interface/station lifecycle, beaconing, receive
filtering, queue selection, key fallback, TX status, and USB transport lifetime.
Mesh is intentionally absent from the existing concurrent-interface
combination.

Hardware RF-path count and userspace antenna selection are distinct. A chipset
with no `set_antenna` operation must not advertise configurable antenna masks;
it continues normal fixed 2T2R operation without a false nl80211 capability.

## Installation

- Manual modules: `/lib/modules/<kernel>/updates/rtl8812au-mesh/`
- DKMS modules on Debian: `/lib/modules/<kernel>/updates/dkms/`
- Firmware: `/lib/firmware/rtw88/rtw8812a_fw.bin`

The package does not overwrite distribution module files in `kernel/`. It does
replace the effective shared `rtw_core` and `rtw_usb` selected by depmod, so an
unrelated `rtw_*` consumer built from another revision is an ABI conflict.

## Test topology

The hardware harness resolves both RTL8812AU radios by permanent MAC and places
one peer in the `meshpeer` network namespace. Every mutating hardware test uses
`/run/lock/rtw88-mesh-test.lock`. Exact five-module provenance is checked before
topology mutation and after module replacement or recovery.

Recovery is udev/systemd driven and version-pinned. It reconstructs only the
test mesh topology and reports success after bilateral peering, traffic, and
HWMP validation.

## USB modes

Both USB2 and USB3 are driver qualification profiles. Set
`rtw_usb.switch_usb_mode=N` before load to prevent the RTL8812AU USB2-to-USB3
transition when testing USB2. The parameter does not downshift an adapter
already enumerated at USB3. Results from different physical USB paths remain
separate evidence rows.
