#!/bin/sh
# Reapply the ordered mail patch series and compare it with production source.

set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
repo_dir=$(dirname "$script_dir")
tag=${1:-upstream-baseline-a56bcd2}
patch_dir=$repo_dir/patches
tmp_dir=$(mktemp -d /tmp/rtl8812au-series-check-XXXXXX)
trap 'rm -rf -- "$tmp_dir"' EXIT INT TERM

"$script_dir/check-upstream-baseline.sh" "$tag" >/dev/null

set -- "$patch_dir"/000*.patch
[ "$#" -eq 9 ] || {
	echo "expected nine ordered patches, found $#" >&2
	exit 1
}

git -C "$repo_dir" archive "$tag" | tar -x -C "$tmp_dir"
git -C "$tmp_dir" init -q

index=1
for patch in "$@"; do
	number=$(printf '%04d' "$index")
	case $(basename "$patch") in
		"$number-"*) ;;
		*) echo "patch $index has an incoherent filename: $patch" >&2; exit 1 ;;
	esac
	subject=$(grep -m1 '^Subject:' "$patch" || true)
	expected="Subject: [PATCH $index/9] "
	case $subject in
		"$expected"*) ;;
		*) echo "patch $index has an incoherent mail subject: $subject" >&2; exit 1 ;;
	esac
	git -C "$tmp_dir" apply --check --whitespace=error-all "$patch"
	git -C "$tmp_dir" apply --whitespace=error-all "$patch"
	index=$((index + 1))
done

for path in main.c mac80211.c usb.c usb.h; do
	cmp -s "$tmp_dir/$path" "$repo_dir/$path" || {
		echo "$path differs after applying the upstream series" >&2
		exit 1
	}
done

echo "baseline=$tag patches=9 mail_headers=coherent final_tree=production-match whitespace=clean"
