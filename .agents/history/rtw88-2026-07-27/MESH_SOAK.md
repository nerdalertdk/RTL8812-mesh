# Overnight mesh soak

## Active service

The Pi is running a transient systemd unit:

```text
mesh-overnight-soak.service
```

`mesh-soak-finish.timer` is scheduled to stop the soak after approximately
eight hours and run `/home/msh/mesh-soak-finish.sh`. The completion script writes
`summary-<run-id>.log` and updates `latest-summary.log`.

It performs:

- continuous `ping -D` from RTL8812AU to RTL8192FU;
- continuous `ping -D` from RTL8192FU to RTL8812AU;
- peer-link and carrier checks every 60 seconds;
- a random 10 MiB HTTP transfer with SHA-256 verification in each direction
  every 3600 seconds;
- automatic cleanup of each pair of temporary transfer files.

Network namespaces and explicit interface binding force all test traffic across
the wireless mesh.

## Logs

```sh
sudo tail -f /home/msh/mesh-soak/latest.log
sudo ls -lh /home/msh/mesh-soak/
sudo journalctl -u mesh-overnight-soak.service
sudo cat /home/msh/mesh-soak/latest-summary.log
```

The two `ping-*.log` files contain timestamped individual ping results. Search
the main log for failures:

```sh
sudo grep -E 'connection-lost|result=failed|hash-mismatch' \
  /home/msh/mesh-soak/latest.log
```

## Stop

```sh
sudo systemctl stop mesh-overnight-soak.service
```

Stopping the service terminates both pings and HTTP servers and deletes its
temporary transfer files. The service is transient and does not survive reboot.

To cancel automatic completion while keeping the soak running:

```sh
sudo systemctl stop mesh-soak-finish.timer
```

## First-run result

The run beginning `2026-07-25T23:11:34Z` was stopped on request at
`2026-07-26T06:34:51Z`.

- 176 minute checks were healthy.
- 269 checks reported both mesh devices missing.
- Three bidirectional hourly transfer pairs passed with matching SHA-256 hashes.
- Five later pairs failed in both directions because the mesh interfaces had
  disappeared.
- RTL8812AU-to-RTL8192FU ping recorded 10,537 replies through sequence 10,561,
  with 24 missing sequences and nine explicit errors.
- The reverse ping recorded 10,537 replies through sequence 10,537 before its
  namespace/device disappeared.
- The Pi reported no undervoltage history (`throttled=0x0`).

The last healthy state was `2026-07-26T02:06:56Z`; the first minute-level loss
was `02:07:56Z`. Kernel logs show RTL8812AU control-transfer failures with USB
error `-71`, followed by disconnect/re-enumeration of RTL8192FU and RTL8812AU on
the shared USB hub. Both drivers re-probed, but only created managed interfaces.
The mesh itself therefore could not recover without userspace reconstruction.
