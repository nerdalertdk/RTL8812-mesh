# Raspberry Pi RTL8812AU mesh test runbook

## Safety conditions

- SSH management must not use the RTL8812AU under test.
- Keep local/serial access available for the first module load if practical.
- Use a stable Pi power supply; record undervoltage events and USB topology.
- Do not install modules persistently for the first experiment.
- Start with an open mesh, fixed permitted 2.4 GHz channel, and HT20.

## 1. Inventory before changing driver state

Capture this output into a timestamped working directory on the Pi:

```sh
uname -a
cat /etc/os-release
dpkg --print-architecture
cat /proc/cmdline
lsusb -t
lsusb -nn
rfkill list
iw --version
iw reg get
iw phy
grep -E 'CONFIG_(CFG80211|MAC80211|MAC80211_MESH|DEBUG_FS)=' \
  /boot/config-"$(uname -r)" /proc/config.gz 2>/dev/null
vcgencmd get_throttled 2>/dev/null || true
readlink -f /sys/bus/usb/devices/*/driver 2>/dev/null
ethtool -i "$(iw dev | awk '$1 == "Interface" {print $2; exit}')" 2>/dev/null || true
journalctl -k -b --no-pager
```

Required kernel capability:

```text
CONFIG_MAC80211_MESH=y
```

## 2. Build the unmodified baseline first

Install the exact running-kernel headers and build tools using the package names
appropriate to the selected Debian/Raspberry Pi kernel. Verify that the header
tree exists before building:

```sh
test -e /lib/modules/"$(uname -r)"/build/Makefile
make -j2
```

Save the complete build output. Do not continue if the baseline tree cannot
build against the running kernel.

## 3. Record current binding and unload only the test-device stack

Identify the interface, PHY, USB sysfs path, and exact bound module before
unloading anything:

```sh
iw dev
lsusb -t
readlink -f /sys/bus/usb/devices/*/driver 2>/dev/null
lsmod | grep -E '(^rtw|rtl8)'
```

Stop only userspace services managing the test interface. Do not stop the
independent SSH management interface. Remove the currently bound RTL8812AU
module stack using its actual names from `lsmod`.

## 4. Load the local experimental modules

Ensure `rtw88/rtw8812a_fw.bin` exists under `/lib/firmware`. Load from the build
directory in dependency order, keeping this first run non-persistent:

```sh
sudo insmod ./rtw_core.ko debug_mask=0x80001 disable_lps_deep=y
sudo insmod ./rtw_88xxa.ko
sudo insmod ./rtw_usb.ko switch_usb_mode=n
sudo insmod ./rtw_8812a.ko
sudo insmod ./rtw_8812au.ko
```

Immediately capture:

```sh
journalctl -k --since '-2 minutes' --no-pager
iw phy
lsusb -t
```

Expected evidence includes `mesh point` under supported interface modes. Also
record whether the driver reports the adapter as 1T1R; otherwise verify two HT
RX MCS masks in `iw phy` as evidence of 2SS advertisement.

## 5. Interface lifecycle smoke test

Replace `phy0` with the discovered test PHY:

First ensure NetworkManager does not change `mesh0` back to managed station
mode. Prefer a persistent unmanaged-device rule. For a short isolated test on a
Pi managed over Ethernet, schedule a recovery before pausing it:

```sh
sudo systemd-run --unit=rtw88-nm-safety --on-active=2m \
  /usr/bin/systemctl start NetworkManager
sudo systemctl stop NetworkManager
```

```sh
sudo iw phy phy0 interface add mesh0 type mp
ip -details link show mesh0
sudo ip link set mesh0 up
iw dev
sudo ip link set mesh0 down
sudo iw dev mesh0 del
journalctl -k --since '-2 minutes' --no-pager
```

Repeat at least ten times before attempting peering. Any warning, firmware error,
USB reset, leaked interface, or failure to recreate the interface is a blocker.

## 6. Open-mesh peering test

Configure the reference node with the same mesh ID, channel, width, and
regulatory domain. Example for channel 1/2412 MHz HT20:

```sh
sudo iw phy phy0 interface add mesh0 type mp
sudo ip link set mesh0 up
sudo iw dev mesh0 mesh join rtw88-test freq 2412 HT20
sudo ip address add 192.0.2.1/24 dev mesh0
```

The interface must be up before `mesh join` on the tested Pi kernel. Verify
`iw dev mesh0 info` still says `type mesh point` immediately before joining.
An `EOPNOTSUPP` response accompanied by `type managed` indicates a userspace
manager changed the interface type; it is not evidence of a driver join failure.

Use `192.0.2.2/24` on the peer. Capture continuously on the reference node if it
supports monitor mode. Evidence commands:

```sh
iw dev mesh0 info
iw dev mesh0 station dump
iw dev mesh0 mpath dump
ip -s link show mesh0
ping -c 20 192.0.2.2
journalctl -k --since '-10 minutes' --no-pager
```

Test bidirectional ping, multicast, sustained `iperf3`, peer leave/rejoin, and
ten mesh leave/join cycles before enabling encryption or HT40.

## 7. Rollback

Leave and remove the mesh interface, then unload the local modules in reverse
dependency order:

```sh
sudo iw dev mesh0 mesh leave 2>/dev/null || true
sudo ip link set mesh0 down 2>/dev/null || true
sudo iw dev mesh0 del 2>/dev/null || true
sudo modprobe -r rtw_8812au rtw_8812a rtw_usb rtw_88xxa rtw_core
```

Because the experimental modules were loaded with `insmod` and not installed,
loading the distribution module again—or rebooting—returns to the baseline.
Capture the final kernel log before rebooting.
