# RTL8812AU mesh driver

An out-of-tree Linux `rtw88` driver package for Realtek RTL8812AU USB Wi-Fi
adapters, with native mac80211 IEEE 802.11s mesh-point support.

It builds exactly this compatible module set:

```text
rtw_8812au -> rtw_8812a -> rtw_88xxa -> rtw_usb + rtw_core
```

> [!WARNING]
> These modules replace the effective `rtw_core` and `rtw_usb` selected by
> `depmod`. Do not install them while another Realtek `rtw_*` device needs a
> different source revision. Keep an independent management connection while
> replacing Wi-Fi modules remotely.

## Status

The current package is `0.1.6`. It has been built, installed, provenance
checked, and exercised on Debian ARM64 with two RTL8812AU adapters.

- Open 802.11s peering, HWMP, unicast, broadcast, and multicast pass.
- SAE/AMPE secured mesh traffic passes using mac80211 software crypto.
- 2.4 GHz HT20 channels 1--13, legal 2.4 GHz HT40-, non-DFS 5 GHz HT20, and
  non-DFS 5 GHz HT40+ were qualified on the recorded test profile.
- A strict 30-minute soak completed 37/37 established-state checks, 74/74
  lossless ping batches, and 12/12 SHA-256-verified transfers, with no scoped
  USB transport event or throttling.

Those results apply to the documented hardware and regulatory profiles, not to
every adapter, host controller, antenna, cable, or country. DFS is unavailable
because this driver does not expose nl80211 radar detection. See
[release gates](docs/RELEASE_GATES.md) for the exact scope and evidence.

## Install with DKMS

On Debian or Ubuntu, install the build tools and headers for the kernel that
will load the driver:

```sh
sudo apt update
sudo apt install build-essential dkms kmod linux-headers-$(uname -r) \
  iw wpasupplicant rfkill util-linux
```

From a source checkout, or after extracting the released source archive:

```sh
tar -xzf rtl8812au-mesh-0.1.6-dkms.tar.gz
cd rtl8812au-mesh-0.1.6
```

Then install with DKMS:

```sh
./scripts/check-loaded-rtw88-conflicts.sh
sudo make install_fw
sudo dkms add .
sudo dkms build rtl8812au-mesh/0.1.6
sudo dkms install --force rtl8812au-mesh/0.1.6
sudo depmod -a
sudo modprobe rtw_8812au
```

Confirm the selected driver and mesh capability:

```sh
modinfo -n rtw_8812au
modinfo -n rtw_usb
iw list | sed -n '/Supported interface modes:/,/Band 1:/p'
```

`mesh point` must appear in the supported interface modes. To remove the DKMS
package:

```sh
sudo dkms remove rtl8812au-mesh/0.1.6 --all
```

## Create an open mesh point

Set the regulatory domain for the location and use a legal channel. This
example creates an open 2.4 GHz HT20 mesh point:

```sh
sudo iw reg set DK
sudo ip link set wlan1 down
sudo iw dev wlan1 set type mesh
sudo ip link set wlan1 up
sudo iw dev wlan1 mesh join my-mesh freq 2412 HT20
sudo ip address add 10.44.0.1/24 dev wlan1
```

Inspect peering and HWMP paths with:

```sh
iw dev wlan1 station dump
iw dev wlan1 mpath dump
```

For a secured mesh, use `wpa_supplicant`. The test configuration in
[`tests/wpa_sae_mesh.conf`](tests/wpa_sae_mesh.conf) contains a public test
passphrase only; replace it before use.

## USB mode and `-71`

Some RTL8812AU devices initially enumerate at USB2 and then intentionally
disconnect to re-enumerate at USB3. The driver handles the narrow expected
status from that transition without hiding unrelated write errors.

For a USB2 test profile, prevent that transition before loading the module:

```conf
# /etc/modprobe.d/rtw88-mesh.conf
options rtw_usb switch_usb_mode=N
```

Reload the matching module stack or reboot, then check `lsusb -t` for `480M`.
This setting does not downshift an adapter already enumerated at USB3, and it
is unrelated to `usb_modeswitch`.

A physical USB disconnect removes the netdev; recovery is necessarily a
userspace/topology concern, not something the interface driver can guarantee.
Do not attribute every `-71` to the driver: collect kernel timestamps, USB
topology, power, and thermal state first.

## Releases and verification

GitHub tag releases contain:

- a DKMS source archive;
- the firmware archive and its redistribution notice;
- modules built by CI against Debian Trixie's AMD64 headers, as a build
  verification artifact only.

Use DKMS to build on the target kernel and architecture; do not install the CI
AMD64 modules on another kernel or architecture.

Run repository-only checks without touching hardware:

```sh
make check-static
```

Hardware harnesses are documented in [tests/README.md](tests/README.md). They
need two dedicated adapters, explicit MAC addresses, and an isolated test
topology. Fault-injection modules are test-only and must never be shipped as
the production driver.

## Development and licensing

The patch series, baseline verification, and upstream submission notes are in
[docs/UPSTREAMING.md](docs/UPSTREAMING.md). Source provenance and firmware
redistribution terms are in [SOURCE.md](SOURCE.md) and `firmware/`.

The project is not affiliated with Realtek. Preserve all SPDX identifiers and
license notices when redistributing source or firmware.
