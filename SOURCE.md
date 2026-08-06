# Source provenance

The driver sources were extracted from the `lwfinger/rtw88` downstream tree at
base commit `a56bcd26e770257612a0803249cbd4095fc6feca` and include the
RTL8812AU mesh and USB-recovery changes developed in a local rtw88 worktree on
2026-07-26. The annotated `upstream-baseline-a56bcd2` tag retains exact copies
of the four production-file blobs from that revision so the focused delta can
be reproduced without importing unrelated source history. Its integrity is
checked by `scripts/check-upstream-baseline.sh`.

Every C/header file retains its original SPDX identifier and copyright notice.
The binary firmware is the matching `rtw8812a_fw.bin` distributed by that
source tree. Its required Realtek binary redistribution notice is included as
`firmware/LICENCE.rtw88-firmware.txt`.

No private keys, certificates, generated signing material, PCI/SDIO transport
implementations, or unrelated chipset implementations were copied.
