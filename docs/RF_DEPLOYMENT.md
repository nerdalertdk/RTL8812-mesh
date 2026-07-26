# RF deployment design

## Objective

The production use case is an off-grid mobile MANET with an approximate 1 km
line-of-sight link target. RTL8812AU was selected because 2x2 adapters marketed
for high conducted power are widely available. The initial radio profile is
2.4 GHz, HT20, and two connected antenna chains.

This is an engineering target, not a range or regulatory claim. A mesh must be
designed around the weakest bidirectional path and the intended node geometry.

## Regulatory model

Deployment is multinational. Maintain a reviewed profile per country containing:

- ISO country code and authoritative source/revision;
- permitted 2.4 GHz frequencies/channels and indoor/outdoor restrictions;
- maximum EIRP and power spectral density;
- antenna type/gain, feed-line loss, and maximum configured conducted power;
- equipment certification or authorization constraints.

Use this relationship for every antenna assembly:

```text
EIRP dBm = conducted TX power dBm + antenna gain dBi - feed-line loss dB
```

Set the Linux regulatory country before creating the mesh and verify the
resulting channel and power limits with `iw`. Driver code must not override the
cfg80211 regulatory decision. Configuration is not proof of radiated power;
high-power adapters may require conducted and radiated measurement because
calibration and marketing claims are not sufficient evidence.

As one example only, the current EU wideband-data profile for 2400--2483.5 MHz
uses a 100 mW (20 dBm) EIRP ceiling and a 10 mW/MHz EIRP density limit for
non-frequency-hopping modulation. Other countries may differ and must have
their own reviewed profile.

## First-order 1 km budget

At 2.437 GHz and 1 km, free-space path loss is approximately 100.2 dB. A node
radiating 20 dBm EIRP into a receiving antenna with 2 dBi gain has an ideal
received level near -78.2 dBm before implementation and environmental losses.
Actual margin depends on measured receiver sensitivity at the selected MCS,
feed losses, polarization, fading, interference, body/vehicle shadowing, and
antenna pattern.

The first Fresnel-zone radius at the midpoint of a 1 km 2.4 GHz link is about
5.5 m; 60% clearance is about 3.3 m. Two handheld antennas near ground level
will not provide that clearance across typical terrain. Elevated relays or one
elevated endpoint are therefore part of the preferred topology.

## Design recommendations

- Keep HT20. It reduces noise/interference exposure and preserves link budget
  compared with wider channels.
- Keep both antenna chains connected. MIMO can provide diversity and throughput,
  but it does not guarantee additional range and the edge link may fall back to
  one spatial stream.
- Separate same-polarization antennas by at least about half a wavelength
  (6.2 cm at 2.4 GHz) where the enclosure permits, and validate the complete
  radiation pattern in realistic node orientations.
- Prefer quality external antennas, short low-loss coax, and radio placement
  close to the antennas. Antenna gain also improves reception, but transmitted
  power must be reduced where necessary to remain within the profile EIRP.
- Use omnidirectional antennas on mobile nodes. Reserve panels/sectors for
  elevated fixed relays or backhaul where their pointing constraints are known.
- Treat the lower-power direction as the range limit. ACKs, peering frames, and
  path-management traffic must all close the return link.
- Provide a stable, separately characterized 5 V supply path for high-power USB
  radios and capture voltage, current, USB topology, and temperature during
  testing. Nominal RF output is only part of adapter power consumption.
- Leave rate control adaptive initially. Do not force a high MCS for a range
  claim; characterize the MCS/retry transition as distance and orientation vary.
- Expect same-channel multi-hop throughput to fall as relays contend for the
  same airtime. Optimize first for robust connectivity and route repair.

## Field validation ladder

Run at 100, 250, 500, 750, and 1000 m, then add points around observed rate or
reliability transitions. At every point test both traffic directions and record:

- coordinates, terrain profile, antenna height, orientation, polarization, and
  weather;
- country profile, frequency, bandwidth, configured power, antenna gain, and
  feed loss;
- RSSI/signal, noise where available, selected MCS/NSS, retries, and failures;
- peer-link and HWMP path state and repair time;
- unicast, multicast, latency/loss, and checksummed transfer throughput;
- supply voltage/current, USB events, and adapter/host temperature.

Repeat with representative body/vehicle obstruction and node motion. A 1 km
success using elevated stationary nodes must not be reported as a 1 km mobile
or handheld result.
