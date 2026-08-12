# Open 512 MiB integrity transfer — 2026-08-12

## Scope

Exact DKMS 0.1.6 RTL8812AU peers ran the open-mesh bidirectional transfer gate
on the validated channel-1 2.4 GHz HT20 topology. The gate generated one 512
MiB random source, transferred it over the mesh in each direction, verified
the SHA-256 after each transfer, required reciprocal HWMP paths afterward, and
captured the full kernel transport interval.

## Result

```
root-to-peer: 536870912 bytes, 106.529057 s, 5,039,666 B/s
peer-to-root: 536870912 bytes,  76.534020 s, 7,014,800 B/s
postflight: root_paths=1 peer_paths=1
complete: result=pass kernel_events=0 elapsed_s=203
```

Both received files matched the generated source SHA-256. The scoped interval
contained no USB `-71`/`-EPROTO`, USB disconnect/reset, or rtw88 RX/TX
transport diagnostic.
