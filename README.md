# RTL8812AU native 802.11s mesh driver

Focused out-of-tree Linux rtw88 package for Realtek RTL8812AU USB adapters with
native mac80211 IEEE 802.11s (`mesh point`) support.

This repository builds only the required module stack:

```text
rtw_8812au -> rtw_8812a -> rtw_88xxa -> rtw_usb + rtw_core
```

It currently targets Debian first. Android and OpenWrt packaging are future
work. The tested RF baseline is 2.4 GHz HT20.

## Current validation

On Debian 13.1 ARM64, Raspberry Pi kernel `6.12.47+rpt-rpi-v8`, the development
build has demonstrated:

- open 802.11s peering and native HWMP paths;
- bidirectional unicast, broadcast, and IPv4 multicast;
- 20/20 fresh churn cycles with 117--133 ms plink times;
- MCS 15 / two-stream operation with the current peer;
- checksummed 512 MiB and repeated 64 MiB transfers;
- bounded recovery from injected USB control and RX `-EPROTO` (`-71`);
- automatic userspace topology reconstruction after module/USB rebind;
- a clean thermal-aware 15-minute direct-port endurance run.

Still required before production claims:

- protected payload validation with a second stable RTL8812AU;
- channels 1--13 hardware sweep;
- original USB2-topology and physical unplug/re-enumeration testing;
- independently powered USB-path and long-duration endurance.

The RTL8192FU test peer is experimental and is not part of this driver package.

## Debian prerequisites

```sh
sudo apt update
sudo apt install build-essential dkms kmod linux-headers-$(uname -r) \
  iw wpasupplicant rfkill
```

Remove or disable any vendor `8812au` driver that already owns the adapter.
Keep Ethernet or another independent management path while replacing Wi-Fi
modules remotely.

## Manual build and installation

```sh
make
sudo make install
sudo make install_fw
```

The modules install under
`/lib/modules/$(uname -r)/updates/rtl8812au-mesh/`; distribution files under
`kernel/` are not overwritten.

To replace a currently loaded matching rtw88 stack:

```sh
sudo modprobe -r rtw_8812au rtw_8812a rtw_88xxa rtw_usb rtw_core
sudo modprobe rtw_8812au
```

Confirm that the packaged module wins lookup order:

```sh
modinfo -n rtw_8812au
modinfo -n rtw_usb
iw list | sed -n '/Supported interface modes:/,/Band 1:/p'
```

`mesh point` must appear in the interface modes.

To remove only the manually installed copies:

```sh
sudo make uninstall
```

## DKMS installation

From the repository root:

```sh
./scripts/check-loaded-rtw88-conflicts.sh
sudo make install_fw
sudo dkms add .
sudo dkms build rtl8812au-mesh/0.1.1
sudo dkms install --force rtl8812au-mesh/0.1.1
sudo depmod -a
```

`--force` is required because Debian already provides unversioned in-tree
modules with these same five names. On Debian DKMS installs the replacements under
`updates/dkms`; it does not delete or overwrite the distribution
copies under `kernel/`.

This package's five-module boundary is a source/package boundary, not a private
kernel ABI namespace. In particular, `rtw_core` and `rtw_usb` have the same
module names used by Debian's other downstream rtw88 drivers. Do not install
this package on a host actively using another `rtw_*` chipset module unless all
consumers were built from the same source revision. The preflight script rejects
an unrelated loaded consumer; it cannot detect hardware whose driver is
currently unloaded but may be needed later. `make install` enforces the check
for a live root and skips it for an explicit `INSTALL_MOD_PATH` staging root.

Remove the DKMS package with:

```sh
sudo dkms remove rtl8812au-mesh/0.1.1 --all
```

## Create an open mesh point

Replace `wlan1`, addresses, mesh ID, and frequency for your deployment. Set the
regulatory country before selecting a channel.

```sh
sudo iw reg set DK
sudo ip link set wlan1 down
sudo iw dev wlan1 set type mesh
sudo ip link set wlan1 up
sudo iw dev wlan1 mesh join my-mesh freq 2412 HT20
sudo ip address add 10.44.0.1/24 dev wlan1
```

Inspect the peer and HWMP state:

```sh
iw dev wlan1 station dump
iw dev wlan1 mpath dump
```

For SAE/AMPE security use `wpa_supplicant`; the test profile in
`tests/wpa_secure_mesh.conf` is an example only and contains a public test
passphrase that must be changed.

## USB `-71` behavior

The transport changes distinguish two classes of failure:

- transient control/RX protocol errors are retried or resubmitted with bounded,
  rate-limited diagnostics;
- a physical USB disconnect destroys the netdev and cannot be repaired solely
  inside the driver. `tests/pi_mesh_recover.sh` and the accompanying udev and
  systemd files reconstruct the test topology after re-enumeration.

The Pi evidence includes a prior simultaneous hub/root-port over-current event
that disconnected both test adapters. Do not interpret every `-71` as an
RTL8812AU mesh-driver defect; retain USB topology, power, temperature, and
kernel timestamps when reporting one.

## Tests

See [tests/README.md](tests/README.md). The scripts default to the development
Pi's MAC addresses and network namespace; override their environment variables
for another topology.

Fault-injection modules and `usb_rx_submit_failure.patch` are test-only. Never
ship an instrumented module as the production driver.

## Source and licensing

See [SOURCE.md](SOURCE.md). Source files retain their SPDX identifiers and
original copyright notices; canonical license texts are under `LICENSES/` and
the firmware redistribution terms accompany the binary in `firmware/`. No
private signing keys or certificates are stored in this repository.
