#!/bin/sh
# Refuse installation while an unrelated module uses the shared rtw88 stack.

set -eu

PROC_MODULES=${PROC_MODULES:-/proc/modules}
if [ ! -r "$PROC_MODULES" ]; then
	echo "cannot read loaded modules from $PROC_MODULES" >&2
	exit 1
fi

conflicts=$(awk '
	$1 ~ /^rtw_/ &&
	$1 != "rtw_core" &&
	$1 != "rtw_usb" &&
	$1 != "rtw_88xxa" &&
	$1 != "rtw_8812a" &&
	$1 != "rtw_8812au" { print $1 }
' "$PROC_MODULES")

if [ -n "$conflicts" ]; then
	echo "unrelated loaded rtw88 modules use the shared module namespace:" >&2
	printf '%s\n' "$conflicts" | sed 's/^/  /' >&2
	echo "stop here; installing a different rtw_core/rtw_usb revision can break those devices" >&2
	exit 1
fi

echo "loaded-module conflict check passed"
