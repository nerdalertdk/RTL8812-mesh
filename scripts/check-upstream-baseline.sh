#!/bin/sh
# Verify the focused four-file baseline used to review the production delta.

set -eu

tag=${1:-upstream-baseline-a56bcd2}

git rev-parse -q --verify "refs/tags/$tag^{commit}" >/dev/null || {
	echo "missing baseline tag: $tag" >&2
	exit 1
}

check_blob()
{
	path=$1
	expected=$2
	actual=$(git rev-parse "$tag:$path" 2>/dev/null || true)
	if [ "$actual" != "$expected" ]; then
		echo "$path baseline mismatch: expected $expected, got ${actual:-missing}" >&2
		exit 1
	fi
}

check_blob main.c 94b3b627cd80e365941d1875e16149937197833f
check_blob mac80211.c 9e583b5a9fac6bbed97be07b80e4cebf0683e53e
check_blob usb.c 95cd1dbe479498ec853a581ea3753d7a0544a37e
check_blob usb.h ae0af4fdd1c131aa9d1866ec3396f1066239d1b7

unexpected=$(git ls-tree -r --name-only "$tag" |
	awk '$0 != "main.c" && $0 != "mac80211.c" &&
	     $0 != "usb.c" && $0 != "usb.h" { print }')
count=$(git ls-tree -r --name-only "$tag" | awk 'END { print NR + 0 }')
if [ "$count" -ne 4 ] || [ -n "$unexpected" ]; then
	echo "baseline tag must contain exactly the four production files" >&2
	[ -z "$unexpected" ] || printf 'unexpected paths:\n%s\n' "$unexpected" >&2
	exit 1
fi

git diff --check "$tag" -- main.c mac80211.c usb.c usb.h
echo "baseline=$tag files=4 blobs=match production_diff=clean"
