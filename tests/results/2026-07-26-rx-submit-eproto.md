# RX submit `-EPROTO` fault-injection result

## Scope

This test validates the driver's RX URB submission retry and teardown paths. It
uses `tests/usb_rx_submit_failure.patch` in an isolated build; it does not claim
to reproduce a physical USB completion error, hub fault, or power fault.

- Host: Raspberry Pi 4, Debian kernel `6.12.47+rpt-rpi-v8`
- RTL8812AU: USB 3 path, `rtw_8812au`
- Peer fixture: RTL8192FU, USB 2 path, `rtl8xxxu`
- Mesh: open 802.11s, channel 1, HT20
- Instrumented `rtw_usb` source version: `0D69A5F68C25FAB2097D24B`
- Production `rtw_usb` source version: `D3CBBAF2BD6E7BED379E412`

## Retry result

Eight pre-submit `-EPROTO` failures were injected, twice the four-slot RX URB
pool size. Traffic drove every slot through completion and resubmission.

- injected failure counter after recovery: `0`
- RX submit success bitmap after recovery: `15` (`0xf`)
- root-to-peer ping: 40/40
- peer-to-root ping: 40/40
- kernel log: eight rate-limited `transient RX URB submit error -71; retrying`
  events and no warning/Oops signature

A subsequent 90-second mesh run remained established and completed six
checksummed 32 MiB transfers (192 MiB total), three in each direction, with no
transfer or ping failure.

## Pending-retry teardown result

The injector was set to 100,000 failures and traffic triggered retry work.
Immediately before unload, 99,981 failures remained, proving the retry path was
still active. Unloading the complete five-module stack took 593 ms.

- all five instrumented modules were absent after unload
- no kernel warning, Oops, UAF, general-protection, or workqueue-after-free
  signature was observed
- the production DKMS stack was restored from `updates/dkms`
- loaded and on-disk production `rtw_usb` source versions matched
- the open mesh re-established and three pings passed in each direction

## Remaining evidence gap

This proves bounded recovery from synthetic RX submission failures and safe
teardown while delayed retry work is active. It does not separate real
`-EPROTO` completion errors caused by the driver from errors caused by the Pi's
USB topology, cable, power supply, or hub. That requires controlled physical
USB2 and independently powered-path runs with two stable RTL8812AU radios.
