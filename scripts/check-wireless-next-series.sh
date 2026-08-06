#!/bin/sh
# Reproduce the full current wireless-next rtw88 series offline.

set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
repo_dir=$(dirname "$script_dir")
series_dir=$repo_dir/patches/wireless-next
tmp_dir=$(mktemp -d /tmp/rtl8812au-wireless-next-check-XXXXXX)
trap 'rm -rf -- "$tmp_dir"' EXIT INT TERM

baseline_main=cd52ce31a39022269a9cf48a35c2e1b89cc8a25ccb0f2ed1cec8425e910dcfa4
baseline_mac80211=5de984df903ec1d96199ecd05b37f7ce3459de575a9439a59ac6f06d47a0853a
baseline_usb=64d44452d287386bdb0de219c6a53ab288aec7762983df6929e798b2bc610a3b
baseline_usb_h=eb30ffd421bbc4e8bc4234dc094a2f3fc9156dfd3e7f8027cb1116a51693797e
final_main=868f48d8b3a4d862df017d0cf491a25d0858d5c689f96d55d792fcc13fc7ed89
final_mac80211=ef38cb3711f9e9da20c29636a0c7806d813fea408fdaf5079fc134466b64343d
final_usb=65672441c218f5c5e4b8e540dbf9d397409afaa2934cfb2c451ab01089b58da7
final_usb_h=7733a79add1c5931f77763cc5b4ecf78e84775aa6c0744a1a12449ffdb54afc0

hash_file()
{
	sha256sum "$1" | awk '{ print $1 }'
}

[ "$(hash_file "$series_dir/baseline/main.c")" = "$baseline_main" ]
[ "$(hash_file "$series_dir/baseline/mac80211.c")" = "$baseline_mac80211" ]
[ "$(hash_file "$series_dir/baseline/usb.c")" = "$baseline_usb" ]
[ "$(hash_file "$series_dir/baseline/usb.h")" = "$baseline_usb_h" ]

target=$tmp_dir/drivers/net/wireless/realtek/rtw88
mkdir -p "$target"
for path in main.c mac80211.c usb.c usb.h; do
	cp "$series_dir/baseline/$path" "$target/$path"
done
git -C "$tmp_dir" init -q

set -- "$series_dir"/000*.patch
[ "$#" -eq 8 ] || {
	echo "expected eight wireless-next patches, found $#" >&2
	exit 1
}

index=1
for patch in "$@"; do
	number=$(printf '%04d' "$index")
	case $(basename "$patch") in
		"$number-"*) ;;
		*) echo "patch $index has an incoherent filename: $patch" >&2; exit 1 ;;
	esac
	subject=$(grep -m1 '^Subject:' "$patch" || true)
	expected="Subject: [PATCH $index/8] "
	case $subject in
		"$expected"*) ;;
		*) echo "patch $index has an incoherent subject: $subject" >&2; exit 1 ;;
	esac
	git -C "$tmp_dir" apply --check --whitespace=error-all "$patch"
	git -C "$tmp_dir" apply --whitespace=error-all "$patch"
	index=$((index + 1))
done

[ "$(hash_file "$target/main.c")" = "$final_main" ]
[ "$(hash_file "$target/mac80211.c")" = "$final_mac80211" ]
[ "$(hash_file "$target/usb.c")" = "$final_usb" ]
[ "$(hash_file "$target/usb.h")" = "$final_usb_h" ]

echo "wireless_next=ca800a930276 patches=8 baseline=match mail_headers=coherent final=match whitespace=clean"
