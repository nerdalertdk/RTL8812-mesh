# RTL8812AU native 802.11s mesh driver

Focused out-of-tree Linux rtw88 package for Realtek RTL8812AU USB adapters with
native mac80211 IEEE 802.11s (`mesh point`) support.

This repository builds only the required module stack:

```text
rtw_8812au -> rtw_8812a -> rtw_88xxa -> rtw_usb + rtw_core
```

It currently targets Debian first. Android and OpenWrt packaging are future
work. The tested RF baseline is 2.4 GHz HT20.

The intended deployment is a multinational off-grid mobile MANET with an
engineering target of approximately 1 km LOS. Range depends on the complete
bidirectional RF system, not the adapter's advertised conducted power. See
[docs/RF_DEPLOYMENT.md](docs/RF_DEPLOYMENT.md) for the preliminary link budget,
country-profile model, antenna guidance, and field-test ladder.

## Current validation

On Debian 13.1 ARM64, Raspberry Pi kernel `6.12.47+rpt-rpi-v8`, the development
build has demonstrated:

- open 802.11s peering and native HWMP paths;
- bidirectional unicast, broadcast, and IPv4 multicast;
- 20/20 fresh churn cycles with 117--133 ms plink times;
- MCS 15 / two-stream operation with the current peer;
- checksummed 512 MiB and repeated 64 MiB transfers;
- symmetric RTL8812AU multicast delivery of 399/400 and 400/400 frames with
  complete sender capture and no USB event;
- symmetric SAE/AMPE with peer-specific SAE acceptance, decrypted AMPE,
  bilateral unicast/multicast/HWMP, and checksummed secured payloads;
- symmetric RTL8812AU channels 1--13 HT20 with fresh peering, bilateral cold
  unicast/multicast, reciprocal HWMP, and no USB event;
- bounded recovery from injected USB control and RX `-EPROTO` (`-71`);
- automatic userspace topology reconstruction after module/USB rebind;
- a clean thermal-aware 4.5-hour direct-port run with 337/337 established
  states, 672/672 ping batches, 10/10 checksummed transfers, and no USB event;
- a completed eight-hour DKMS 0.1.2 run with 597/597 established states,
  1,194/1,194 ping batches, 16/16 checksummed transfers, and no recovery or
  measured USB transport event;
- a bidirectional checksummed 512 MiB transfer on DKMS 0.1.1;
- an audited DKMS 0.1.2 production build with strict 20-cycle churn and
  pending-RX-retry teardown validation; DKMS 0.1.4 additionally serializes
  complete synchronous USB control transactions and passed exact-kernel
  build, injection, churn, transfer, and bounded-soak validation. Source 0.1.5
  additionally releases every skb after a failed USB TX submission and reports
  failed TX completions to mac80211 without a false ACK; exact-kernel build and
  hardware fault-injection validation remain pending.

Still required before production claims:

- original USB2-topology and physical unplug/re-enumeration testing;
- independently powered USB-path and thermally clean long-duration endurance.

The RTL8192FU test peer is experimental and is not part of this driver package.

## Debian prerequisites

```sh
sudo apt update
sudo apt install build-essential dkms kmod linux-headers-$(uname -r) \
  iw wpasupplicant rfkill util-linux
```

`util-linux` supplies `flock`, which every hardware-test entry point requires
to enforce exclusive ownership of the radios and mesh topology. The extended
hardware harness also uses `curl`, `iproute2`, `python3`, and `tcpdump`.

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
sudo dkms build rtl8812au-mesh/0.1.5
sudo dkms install --force rtl8812au-mesh/0.1.5
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
sudo dkms remove rtl8812au-mesh/0.1.5 --all
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

For SAE/AMPE security use `wpa_supplicant`; the canonical test profile in
`tests/wpa_sae_mesh.conf` is an example only and contains a public test
passphrase that must be changed. `tests/pi_secure_mesh.sh` requires both peers
to report `wpa_state=COMPLETED`, verifies configured SAE plus peer-specific SAE
acceptance and decrypted AMPE, then validates directional unicast, multicast,
and HWMP. This handles `wpa_supplicant` 2.10 reporting `key_mgmt=UNKNOWN` for a
completed mesh group. Set `TRANSFER_TEST=tests/pi_mesh_transfer.sh` to also run
a bidirectional checksummed payload gate under the secured topology.

## USB `-71` behavior

The transport changes distinguish two classes of failure:

- transient control/RX protocol errors are retried or resubmitted with bounded,
  rate-limited diagnostics;
- failed TX submissions release their skb/context ownership, while TX
  completion errors are reported to mac80211 without ACK. They are not blindly
  replayed because a completion error does not prove that the device received
  none of the frame;
- with `rtw_usb.switch_usb_mode=Y` (the default), an old-chip RTL8812AU that
  first enumerates at USB2 may deliberately disconnect and re-enumerate at
  USB3. The final write to `REG_SYS_PW_CTRL + 1` can therefore return
  `-EPROTO`, `-ENODEV`, or `-ESHUTDOWN` as the device disappears. Version 0.1.4
  classifies only this narrow, intentional transition as expected; it does not
  retry the write or hide other write failures;
- a physical USB disconnect destroys the netdev and cannot be repaired solely
  inside the driver. `tests/pi_mesh_recover.sh` and the accompanying udev and
  systemd files reconstruct the test topology after re-enumeration and require
  exact module/driver provenance, bilateral peering, bidirectional traffic, and
  HWMP paths before reporting recovery.

The Pi evidence includes a prior simultaneous hub/root-port over-current event
that disconnected both test adapters. Do not interpret every `-71` as an
RTL8812AU mesh-driver defect; retain USB topology, power, temperature, and
kernel timestamps when reporting one.

For 2.4 GHz deployments, validate both USB modes. USB3 can create local
2.4 GHz interference, while USB2 limits host throughput and changes the
physical USB path. The intended deployment baseline is USB2, pending completion
of the physical USB2 matrix: set `rtw_usb.switch_usb_mode=N` before module load
to retain USB2. Keep USB3 as an explicit required regression profile. For a
persistent Debian configuration:

```conf
# /etc/modprobe.d/rtw88-mesh.conf
options rtw_usb switch_usb_mode=N
```

Reload the matching five-module stack or reboot, then confirm `lsusb -t`
reports the adapter at `480M`. This parameter is unrelated to `usb_modeswitch`,
which handles devices initially presenting as CD-ROM storage.

## Tests

See [tests/README.md](tests/README.md). Hardware scripts require explicit
`ROOT_MAC` and `PEER_MAC` values and otherwise use the documented test network
namespace defaults; no development adapter identities are embedded.

Fault-injection modules, `usb_rx_submit_failure.patch`, and
`usb_tx_failure_injection.patch` are test-only. Never ship an instrumented
module as the production driver.

The requirement-by-requirement release verdict and authoritative evidence are
tracked in [docs/RELEASE_GATES.md](docs/RELEASE_GATES.md).

## Source and licensing

See [SOURCE.md](SOURCE.md). Source files retain their SPDX identifiers and
original copyright notices; canonical license texts are under `LICENSES/` and
the firmware redistribution terms accompany the binary in `firmware/`. No
private signing keys or certificates are stored in this repository.
