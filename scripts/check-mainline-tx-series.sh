#!/bin/sh
# Reproduce the pinned current-mainline rtw88 USB TX delta offline.

set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
repo_dir=$(dirname "$script_dir")
series_dir=$repo_dir/patches/mainline
tmp_dir=$(mktemp -d /tmp/rtl8812au-mainline-check-XXXXXX)
trap 'rm -rf -- "$tmp_dir"' EXIT INT TERM

baseline_usb_c=64d44452d287386bdb0de219c6a53ab288aec7762983df6929e798b2bc610a3b
baseline_usb_h=eb30ffd421bbc4e8bc4234dc094a2f3fc9156dfd3e7f8027cb1116a51693797e
final_usb_c=3808e0e06703bbbcf9988ded191b745fc187f53786f30b6bd1533f47db45a117
final_usb_h=9a95181908d1c1bf5aafea5dd42accbe5725f6318375e3e2da7cbf1123617a0b

hash_file()
{
	sha256sum "$1" | awk '{ print $1 }'
}

[ "$(hash_file "$series_dir/baseline/usb.c")" = "$baseline_usb_c" ] || {
	echo "pinned mainline usb.c hash mismatch" >&2
	exit 1
}
[ "$(hash_file "$series_dir/baseline/usb.h")" = "$baseline_usb_h" ] || {
	echo "pinned mainline usb.h hash mismatch" >&2
	exit 1
}

target=$tmp_dir/drivers/net/wireless/realtek/rtw88
mkdir -p "$target"
cp "$series_dir/baseline/usb.c" "$target/usb.c"
cp "$series_dir/baseline/usb.h" "$target/usb.h"
git -C "$tmp_dir" init -q

set -- "$series_dir"/000*.patch
[ "$#" -eq 2 ] || {
	echo "expected two pinned mainline patches, found $#" >&2
	exit 1
}
for patch in "$@"; do
	git -C "$tmp_dir" apply --check --whitespace=error-all "$patch"
	git -C "$tmp_dir" apply --whitespace=error-all "$patch"
done

[ "$(hash_file "$target/usb.c")" = "$final_usb_c" ] || {
	echo "patched mainline usb.c hash mismatch" >&2
	exit 1
}
[ "$(hash_file "$target/usb.h")" = "$final_usb_h" ] || {
	echo "patched mainline usb.h hash mismatch" >&2
	exit 1
}

echo "linux=315f4bd234b3 patches=2 baseline=match final=match whitespace=clean"
