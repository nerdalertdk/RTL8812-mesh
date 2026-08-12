#!/bin/sh
# Create redistributable source and firmware archives from tracked source.

set -eu

repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
output_dir=${1:-$repo_dir/dist}
package_name=$(sed -n 's/^PACKAGE_NAME="\([^"]*\)"$/\1/p' "$repo_dir/dkms.conf")
package_version=$(sed -n 's/^PACKAGE_VERSION="\([^"]*\)"$/\1/p' "$repo_dir/dkms.conf")

[ -n "$package_name" ] || { echo "PACKAGE_NAME missing from dkms.conf" >&2; exit 2; }
[ -n "$package_version" ] || { echo "PACKAGE_VERSION missing from dkms.conf" >&2; exit 2; }

source_root=$package_name-$package_version
tmp_dir=$(mktemp -d "${TMPDIR:-/tmp}/$package_name-release.XXXXXX")
trap 'rm -rf "$tmp_dir"' EXIT HUP INT TERM

mkdir -p "$output_dir" "$tmp_dir/source" \
	"$tmp_dir/firmware/lib/firmware/rtw88"

git -C "$repo_dir" archive --format=tar --prefix="$source_root/" HEAD |
	tar -x -C "$tmp_dir/source"
tar -C "$tmp_dir/source" -czf "$output_dir/$source_root-dkms.tar.gz" "$source_root"

cp "$repo_dir/firmware/rtw8812a_fw.bin" \
	"$tmp_dir/firmware/lib/firmware/rtw88/rtw8812a_fw.bin"
cp "$repo_dir/firmware/LICENCE.rtw88-firmware.txt" \
	"$tmp_dir/firmware/LICENCE.rtw88-firmware.txt"
tar -C "$tmp_dir/firmware" -czf "$output_dir/$source_root-firmware.tar.gz" \
	lib LICENCE.rtw88-firmware.txt

printf 'source=%s\nfirmware=%s\n' \
	"$output_dir/$source_root-dkms.tar.gz" \
	"$output_dir/$source_root-firmware.tar.gz"
