#!/bin/sh
# Build the release DKMS source archive and package its five modules.

set -eu

repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
output_dir=${1:-$repo_dir/dist}
package=$(sed -n 's/^PACKAGE_NAME="\([^"]*\)"$/\1/p' "$repo_dir/dkms.conf")
version=$(sed -n 's/^PACKAGE_VERSION="\([^"]*\)"$/\1/p' "$repo_dir/dkms.conf")
kernel=$(find /lib/modules -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | sort -V | tail -n 1)
architecture=$(dpkg --print-architecture)

[ -n "$package" ] || { echo "PACKAGE_NAME missing from dkms.conf" >&2; exit 2; }
[ -n "$version" ] || { echo "PACKAGE_VERSION missing from dkms.conf" >&2; exit 2; }
[ -n "$kernel" ] || { echo "no installed kernel headers found" >&2; exit 2; }

extract=$(mktemp -d)
trap 'rm -rf "$extract"' EXIT HUP INT TERM

tar -xzf "$output_dir/$package-$version-dkms.tar.gz" -C "$extract"
cp -a "$extract/$package-$version" "/usr/src/$package-$version"
dkms add -m "$package" -v "$version"
dkms build -m "$package" -v "$version" -k "$kernel"
dkms install -m "$package" -v "$version" -k "$kernel"

module_dir="/lib/modules/$kernel/updates/dkms"

mkdir -p "$output_dir/modules"
for module in rtw_core rtw_usb rtw_88xxa rtw_8812a rtw_8812au; do
	[ -f "$module_dir/$module.ko" ] || {
		echo "DKMS did not install $module_dir/$module.ko" >&2
		exit 1
	}
	cp "$module_dir/$module.ko" "$output_dir/modules/"
done
printf 'package=%s\nversion=%s\nkernel=%s\narchitecture=%s\n' \
	"$package" "$version" "$kernel" "$architecture" > "$output_dir/modules/BUILD-INFO"
tar -C "$output_dir" -czf "$package-$version-debian-trixie-$architecture-$kernel-modules.tar.gz" modules

printf 'package=%s\nversion=%s\nkernel=%s\narchitecture=%s\n' \
	"$package" "$version" "$kernel" "$architecture"
