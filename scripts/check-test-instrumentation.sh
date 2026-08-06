#!/bin/sh
# Verify disposable USB fault instrumentation against exact production source.

set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
repo_dir=$(dirname "$script_dir")
tmp_dir=$(mktemp -d /tmp/rtl8812au-test-patches-XXXXXX)
trap 'rm -rf -- "$tmp_dir"' EXIT INT TERM

check_patch()
{
	patch=$1
	cp "$repo_dir/usb.c" "$tmp_dir/usb.c"
	git -C "$tmp_dir" init -q
	git -C "$tmp_dir" apply --check --whitespace=error-all "$patch"
	git -C "$tmp_dir" apply --whitespace=error-all "$patch"
}

check_patch "$repo_dir/tests/usb_rx_submit_failure.patch"
check_patch "$repo_dir/tests/usb_tx_failure_injection.patch"

grep -q 'test: cleaned rejected aggregate USB TX originals=%u' \
	"$tmp_dir/usb.c"
grep -q '\[ "$aggregate_cleanups" -eq "$FAILURES" \]' \
	"$repo_dir/tests/pi_usb_tx_failure_test.sh"
grep -q '\[ "$aggregate_cleanup_values_valid" -eq 1 \]' \
	"$repo_dir/tests/pi_usb_tx_failure_test.sh"

echo "test_instrumentation=2 production_source=match whitespace=clean aggregate_cleanup_gate=matched"
