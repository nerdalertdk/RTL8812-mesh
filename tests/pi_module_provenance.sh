#!/bin/sh
# Verify one exact installed and loaded five-module RTL8812AU mesh stack.

set -eu

PACKAGE_NAME=${PACKAGE_NAME:-rtl8812au-mesh}
EXPECTED_VERSION=${EXPECTED_VERSION:?set EXPECTED_VERSION to the DKMS package version}
MODINFO=${MODINFO:-/sbin/modinfo}
DKMS=${DKMS:-/usr/sbin/dkms}
PROC_MODULES=${PROC_MODULES:-/proc/modules}
MODULE_PATH_PATTERN=${MODULE_PATH_PATTERN:-*/updates/dkms/*}
modules='rtw_core rtw_usb rtw_88xxa rtw_8812a rtw_8812au'
kernel=$(uname -r)
arch=$(uname -m)

[ -x "$MODINFO" ] || { echo "modinfo is required at $MODINFO" >&2; exit 2; }
[ -x "$DKMS" ] || { echo "dkms is required at $DKMS" >&2; exit 2; }
[ -r "$PROC_MODULES" ] || { echo "cannot read $PROC_MODULES" >&2; exit 2; }
command -v sha256sum >/dev/null 2>&1 || { echo "sha256sum is required" >&2; exit 2; }

dkms_line=$($DKMS status "$PACKAGE_NAME/$EXPECTED_VERSION" -k "$kernel" 2>/dev/null |
	grep -F "$PACKAGE_NAME/$EXPECTED_VERSION, $kernel, $arch: installed" || true)
[ -n "$dkms_line" ] || {
	echo "exact DKMS package is not installed for $kernel/$arch" >&2
	exit 1
}

conflicts=$(awk '
	$1 ~ /^rtw_/ &&
	$1 != "rtw_core" && $1 != "rtw_usb" && $1 != "rtw_88xxa" &&
	$1 != "rtw_8812a" && $1 != "rtw_8812au" { print $1 }
' "$PROC_MODULES")
[ -z "$conflicts" ] || {
	echo "unrelated shared rtw88 modules are loaded:" >&2
	printf '%s\n' "$conflicts" >&2
	exit 1
}

count=0
for module in $modules; do
	grep -q "^$module " "$PROC_MODULES" || {
		echo "$module is not loaded" >&2
		exit 1
	}
	path=$($MODINFO -n "$module")
	case $path in
		$MODULE_PATH_PATTERN) ;;
		*) echo "$module resolves outside $MODULE_PATH_PATTERN: $path" >&2; exit 1 ;;
	esac
	installed=$($MODINFO -F srcversion "$module")
	loaded=$(cat "/sys/module/$module/srcversion")
	[ -n "$installed" ] && [ "$installed" = "$loaded" ] || {
		echo "$module srcversion mismatch installed=$installed loaded=$loaded" >&2
		exit 1
	}
	set -- $($MODINFO -F vermagic "$module")
	[ "${1:-}" = "$kernel" ] || {
		echo "$module vermagic mismatch: $*" >&2
		exit 1
	}
	hash=$(sha256sum "$path" | awk '{ print $1 }')
	printf 'module=%s srcversion=%s sha256=%s path=%s\n' \
		"$module" "$loaded" "$hash" "$path"
	count=$((count + 1))
done

[ "$count" -eq 5 ]
printf 'result=pass package=%s version=%s kernel=%s arch=%s modules=%s conflicts=0\n' \
	"$PACKAGE_NAME" "$EXPECTED_VERSION" "$kernel" "$arch" "$count"
