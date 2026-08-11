#!/bin/sh
# Keep the standalone source gate build-only and five-module scoped.

set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
repo_dir=$(dirname "$script_dir")
gate=$repo_dir/tests/pi_dkms_build_only.sh

sh -n "$gate"
grep -q "^modules='rtw_core rtw_usb rtw_88xxa rtw_8812a rtw_8812au'$" "$gate"
grep -q "action=build-only" "$gate"
grep -q "unexpected staged source entries" "$gate"

if grep -Eq '(^|[[:space:]])(insmod|modprobe)([[:space:]]|$)|\$DKMS[[:space:]]+install' \
	"$gate"; then
	echo "standalone DKMS gate contains an install/load action" >&2
	exit 1
fi

echo "dkms_build_only=flat-source manifest=required modules=5 install=absent load=absent"
