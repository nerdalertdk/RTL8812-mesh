# RTL8192FU reference-side mesh experiment

## Hardware and source

- USB ID: `0bda:f192`
- Kernel identification: RTL8192FU revision B, 2T2R
- Driver: `rtl8xxxu`
- Exact source package: `linux-source-6.12_6.12.47-1+rpt1_all.deb`
- Running kernel: `6.12.47+rpt-rpi-v8`

The distribution driver exposes mac80211 mesh commands but does not advertise
`NL80211_IFTYPE_MESH_POINT`. The temporary module adds mesh only for
`RTL8192F`, maps it to the hardware AP link type, reuses AP beacon and receive
filter setup, and allocates peer MAC IDs through the AP station path.

The source and built module remain on the Pi under
`/home/msh/rtl8xxxu-mesh-src/`. Nothing was installed below `/lib/modules`.

## Test topology

```text
root namespace                         meshpeer namespace
RTL8812AU / rtw_8812au                 RTL8192FU / rtl8xxxu
mesh8812 10.44.0.1/24   <--- RF --->   mesh8192 10.44.0.2/24
fc:22:1c:30:08:c1                      1c:bf:ce:f3:78:4d
```

Both interfaces joined open mesh ID `overnight-mesh` on 2412 MHz HT20. Moving
one PHY to a network namespace prevents Linux from satisfying the traffic via a
local route and makes successful ping evidence of actual wireless data flow.

## Validated evidence

- Both peers reported `mesh plink: ESTAB`, authenticated, associated, and
  authorized.
- Both directions negotiated HT MCS15; observed rates reached 144.4 Mbit/s TX
  and 130 Mbit/s RX.
- Initial five-packet tests passed in both directions with zero loss.
- Two subsequent 100-packet tests passed in both directions with zero loss.
- A 536,870,912-byte HTTP file transfer crossed from `mesh8192` to `mesh8812`
  in 53.567 seconds at 10,022,366 bytes/s (about 80.2 Mbit/s). Source and
  destination SHA-256 were both
  `9acca8e8c22201155389f65abbf6bc9723edc7384ead80503839f49dcc56d767`.
- No link-layer RX/TX errors or drops were reported by either mesh netdev.
- `vcgencmd get_throttled` reported `0x0` with both adapters active.

The HTTP server was bound to `10.44.0.2` inside `meshpeer`, and the client was
bound to `mesh8812`, so the transfer could not use a local socket shortcut. Both
temporary 512 MiB files were deleted after verification.

## Known limitation

A unilateral RTL8192FU leave/rejoin re-established the mesh peer link, but
RTL8812AU-to-RTL8192FU IP traffic did not immediately recover. Reverse traffic
from RTL8192FU populated neighbor/HWMP state, after which bidirectional ping
again passed. Peer churn recovery requires further diagnosis.

An SAE/AMPE experiment also found that `wpa_supplicant` could join the secured
mesh and discover RTL8812AU, but its attempt to update the RTL8192FU beacon
returned `-EOPNOTSUPP`. RTL8812AU received and acknowledged SAE commits but had
not learned RTL8192FU as a candidate, so the exchange could not proceed to key
installation. This is a limitation of the temporary reference-side patch and
does not establish an RTL8812AU security defect.

## Runtime and rollback

The current experiment uses a reboot-ephemeral NetworkManager rule:

```text
/run/NetworkManager/conf.d/99-rtw88-mesh-unmanaged.conf
```

The modules were loaded with `insmod`, so a reboot restores the distribution
`rtl8xxxu` driver and leaves RTL8812AU unbound. To dismantle without rebooting,
leave both meshes, delete namespace `meshpeer`, unload the out-of-tree modules,
and load the distribution `rtl8xxxu` with `modprobe`.
