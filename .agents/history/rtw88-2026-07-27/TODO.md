# TODO.md

## Backlog

- [ ] Select and inventory an unmodified known-good 802.11s peer.
- [x] Inventory the Raspberry Pi model, Debian release, architecture, kernel,
  kernel config, power supply, USB topology, and management interface.
- [x] Establish a reproducible native Pi build and module deployment workflow.
- [x] Confirm whether this adapter reports 2T2R/2SS or an efuse-limited 1T1R mode.
- [x] Set and verify the regulatory domain and permitted 2.4 GHz channels.
- [x] Add minimal RTL8812AU USB-only mesh-point capability advertisement.
- [x] Test mesh interface create/remove and capture failures.
- [ ] Configure NetworkManager to ignore the manual mesh interface.
- [x] Validate beacon TX/RX and open-mesh peering between the two experimental adapters.
- [ ] Audit mesh peer MAC-ID, station-state, BSSID, and receive-filter handling.
- [ ] Test forwarding, multicast, path discovery, peer churn, and endurance.
- [x] Review the active recovery-aware eight-hour direct-port soak started
  2026-07-26 13:39 CEST, including thermal, USB, recovery, ping, and transfer
  evidence. Do not treat it as independently powered-path validation.
- [x] Review the stopped soak for ping loss, connection-loss state, failed
  transfers, hash mismatches, rate changes, and kernel errors.
- [x] Complete an uncontended thermal-aware 15-minute direct-port endurance run
  with 27/27 states, 54/54 ping batches, and 14/14 hashed 64 MiB transfers.
- [ ] Extend uncontended direct-port endurance to a long unattended run.
- [ ] Repeat the soak with each adapter on a separate powered USB root path.
- [ ] Capture USB power and host-controller diagnostics around the simultaneous
  disconnect and determine whether RTL8812AU `-EPROTO` initiates the hub reset.
- [x] Prevent transient RX `-EPROTO` completions from draining the RX URB pool;
  validate beyond the four-URB pool size with one-shot fault injection.
- [x] Validate bounded RTL8812AU register-control retry with a targeted one-shot
  `-EPROTO` kretprobe and matching-call count.
- [x] Add automatic reconstruction of namespaces and mesh interfaces after USB
  disconnect/re-probe; validate single and simultaneous driver rebind recovery.
- [ ] Validate native HWMP path discovery and repair independently (candidate
  mesh broadcast queue fix passes five fresh joins; USB2 A/B still required).
- [x] Make the churn regression resolve both radios by MAC and fail closed when
  any join, plink, cold contact, multicast, or path-table gate fails.
- [ ] Validate HT/VHT and secured mesh after basic operation is stable.
- [x] Reach mutual SAE/AMPE authenticated, authorized, MFP `ESTAB` and identify
  the rtw88 CAM path as unsuitable for mesh per-peer key selection.
- [ ] Validate the RTL8812AU mac80211 software-crypto fallback against a stable
  secured mesh peer, including unicast, ARP, multicast, and MFP.
- [ ] Validate HT20 2SS/MCS15 rate selection when supported by both peers.
- [ ] Plan Android kernel/build/userspace integration after Debian validation.
- [ ] Decide whether support is RTL8812AU-specific or safe for shared rtw88 core.

## In Progress

- [x] Provision the headless Debian Raspberry Pi and enable SSH access.
- [ ] Enable and validate native 802.11s mesh-point support in the driver.
- [ ] Isolate and fix or reliably recover from RTL8812AU USB `-EPROTO` (`-71`).

## Completed

- [x] Identify the attached adapter as Realtek USB `0bda:8812`.
- [x] Identify the development host as Apple Silicon macOS 26.5.
- [x] Confirm that runtime driver testing cannot occur directly on the host OS.
- [x] Select Debian as the first target OS and Android as the second.
- [x] Select 2.4 GHz HT20 as the initial RF configuration.
- [x] Define the end goal as a self-operated MANET using RTL8812AU mesh points.
- [x] Audit dormant mesh-aware interface, beacon, peer, RX-filter, and PS paths.
- [x] Compile the experimental patch against Debian 12 ARM64 6.1.177 headers.
- [x] Prepare a non-persistent Pi test and rollback runbook.
- [x] Build and load the modules on Debian 13.1 / Pi kernel 6.12.47.
- [x] Join an open channel 1 HT20 mesh with no peer present.
- [x] Identify the second adapter as RTL8192FU `0bda:f192`, not RTL8812EU.
- [x] Build a matching-kernel, RTL8192F-scoped experimental mesh patch.
- [x] Establish an open RTL8812AU-to-RTL8192FU mesh peer link on channel 1 HT20.
- [x] Validate namespace-isolated bidirectional IP traffic with zero packet loss.
- [x] Transfer and checksum 512 MiB across the namespace-isolated mesh at about
  80.2 Mbit/s with zero TX failures.
- [x] Start continuous bidirectional ping and hourly bidirectional 10 MiB
  checksum transfers under a managed transient systemd service.
