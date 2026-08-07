# AGENTS.md

## Bootstrap

Also use global user context when available:

- `~/.agent/ME.md`

# Repository instructions

- Preserve the five-module package boundary: `rtw_core`, `rtw_usb`,
  `rtw_88xxa`, `rtw_8812a`, and `rtw_8812au`.
- Keep private keys, generated signing material, and unrelated chipset sources
  out of this repository.
- Build against the exact target kernel before loading modules.
- Serialize hardware tests with `/run/lock/rtw88-mesh-test.lock`.
