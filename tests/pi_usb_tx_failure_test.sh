#!/bin/sh
# Exercise test-only RTL88 USB TX submission and completion -EPROTO handling.

set -eu

IW=${IW:-/usr/sbin/iw}
ROOT_MAC=${ROOT_MAC:?set ROOT_MAC to the primary adapter MAC}
PEER_MAC=${PEER_MAC:?set PEER_MAC to the peer adapter MAC}
PEER_NS=${PEER_NS:-meshpeer}
ROOT_IP=${ROOT_IP:-10.44.0.1}
PEER_IP=${PEER_IP:-10.44.0.2}
ROOT_DRIVER=${ROOT_DRIVER:-rtw_8812au}
PEER_DRIVER=${PEER_DRIVER:-rtw_8812au}
LOCK_FILE=${LOCK_FILE:-/run/lock/rtw88-mesh-test.lock}
FAILURES=${FAILURES:-32}
PHASE_TIMEOUT_SECONDS=${PHASE_TIMEOUT_SECONDS:-30}
LOG_DIR=${LOG_DIR:-/var/tmp/rtl8812au-mesh/usb-tx-failure}
submit_param=/sys/module/rtw_usb/parameters/test_tx_submit_failures
agg_submit_param=/sys/module/rtw_usb/parameters/test_tx_agg_submit_failures
completion_param=/sys/module/rtw_usb/parameters/test_tx_completion_failures

[ "$(id -u)" -eq 0 ] || { echo "run this hardware test as root" >&2; exit 2; }
command -v flock >/dev/null 2>&1 || { echo "flock is required" >&2; exit 2; }
command -v journalctl >/dev/null 2>&1 || { echo "journalctl is required" >&2; exit 2; }
case $FAILURES:$PHASE_TIMEOUT_SECONDS in
	*[!0-9:]*|0:*|*:0) echo "failure count and timeout must be positive integers" >&2; exit 2 ;;
esac
[ -x "$IW" ] || { echo "iw is required at $IW" >&2; exit 2; }
[ -w "$submit_param" ] && [ -w "$agg_submit_param" ] &&
   [ -w "$completion_param" ] || {
	echo "test-only TX failure parameters are unavailable" >&2
	exit 2
}

exec 9>"$LOCK_FILE"
if ! flock -n 9; then
	echo "another rtw88 mesh test holds $LOCK_FILE" >&2
	exit 75
fi

ns()
{
	ip netns exec "$PEER_NS" "$@"
}

find_root_if()
{
	ip -o link 2>/dev/null | awk -v mac="$ROOT_MAC" '
		tolower($0) ~ tolower(mac) { sub(/:$/, "", $2); print $2; exit }
	'
}

find_peer_if()
{
	ns ip -o link 2>/dev/null | awk -v mac="$PEER_MAC" '
		tolower($0) ~ tolower(mac) { sub(/:$/, "", $2); print $2; exit }
	'
}

ROOT_IF=$(find_root_if)
PEER_IF=$(find_peer_if)
[ -n "$ROOT_IF" ] && [ -n "$PEER_IF" ] || {
	echo "mesh interfaces are unavailable" >&2
	exit 1
}
root_driver=$(basename "$(readlink "/sys/class/net/$ROOT_IF/device/driver")")
peer_driver=$(ns basename "$(ns readlink "/sys/class/net/$PEER_IF/device/driver")")
[ "$root_driver" = "$ROOT_DRIVER" ] && [ "$peer_driver" = "$PEER_DRIVER" ] || {
	echo "driver mismatch root=$root_driver peer=$peer_driver" >&2
	exit 2
}

mkdir -p "$LOG_DIR"
run_id=$(date -u +%Y%m%dT%H%M%SZ)
log=$LOG_DIR/tx-failure-$run_id.log
kernel_log=$LOG_DIR/tx-failure-$run_id-kernel.log
echo "result_log=$log kernel_log=$kernel_log"
exec >"$log" 2>&1

cleanup()
{
	printf '0\n' >"$submit_param" 2>/dev/null || true
	printf '0\n' >"$agg_submit_param" 2>/dev/null || true
	printf '0\n' >"$completion_param" 2>/dev/null || true
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

mesh_valid()
{
	$IW dev "$ROOT_IF" station dump |
		grep -q 'mesh plink:[[:space:]]*ESTAB' &&
		ns $IW dev "$PEER_IF" station dump |
		grep -q 'mesh plink:[[:space:]]*ESTAB'
}

traffic_valid()
{
	ping -I "$ROOT_IF" -c 10 -W 1 "$PEER_IP" >/dev/null 2>&1 &&
		ns ping -I "$PEER_IF" -c 10 -W 1 "$ROOT_IP" >/dev/null 2>&1
}

paths_valid()
{
	root_paths=$($IW dev "$ROOT_IF" mpath dump 2>/dev/null |
		awk 'NR > 1 { count++ } END { print count + 0 }')
	peer_paths=$(ns $IW dev "$PEER_IF" mpath dump 2>/dev/null |
		awk 'NR > 1 { count++ } END { print count + 0 }')
	[ "$root_paths" -gt 0 ] && [ "$peer_paths" -gt 0 ]
}

drive_aggregate_burst()
{
	# A single sequential ping stream may drain before mac80211 hands enough
	# frames to the USB aggregation queue.  Concurrent flood bursts make the
	# aggregate-only injection prove the real multi-frame cleanup path.
	burst_pids=
	for _ in 1 2 3 4; do
		ping -I "$ROOT_IF" -f -q -c 128 -s 1400 -W 1 "$PEER_IP" \
			>/dev/null 2>&1 &
		burst_pids="$burst_pids $!"
		ns ping -I "$PEER_IF" -f -q -c 128 -s 1400 -W 1 "$ROOT_IP" \
			>/dev/null 2>&1 &
		burst_pids="$burst_pids $!"
	done
	for burst_pid in $burst_pids; do
		wait "$burst_pid" || true
	done
}

drive_phase()
{
	label=$1
	param=$2
	marker=${3:-}
	phase_start=$(date +%s)
	deadline=$((phase_start + PHASE_TIMEOUT_SECONDS))

	printf '%s\n' "$FAILURES" >"$param"
	while [ "$(cat "$param")" -gt 0 ] && [ "$(date +%s)" -lt "$deadline" ]; do
		if [ "$label" = aggregate-submission ]; then
			drive_aggregate_burst
		else
			ping -I "$ROOT_IF" -c 64 -s 1400 -i 0.001 -W 1 \
				"$PEER_IP" >/dev/null 2>&1 || true
			ns ping -I "$PEER_IF" -c 64 -s 1400 -i 0.001 -W 1 \
				"$ROOT_IP" >/dev/null 2>&1 || true
		fi
	done
	remaining=$(cat "$param")
	phase_events=$(journalctl -k --since "@$phase_start" --no-pager 2>/dev/null |
		grep -c 'USB TX URB error -71' || true)
	marker_events=0
	if [ -n "$marker" ]; then
		marker_events=$(journalctl -k --since "@$phase_start" --no-pager 2>/dev/null |
			grep -c "$marker" || true)
	fi
	printf 'phase=%s requested=%s remaining=%s diagnostics=%s markers=%s\n' \
		"$label" "$FAILURES" "$remaining" "$phase_events" "$marker_events"
	[ "$remaining" -eq 0 ] && [ "$phase_events" -gt 0 ] &&
		{ [ -z "$marker" ] || [ "$marker_events" -eq "$FAILURES" ]; }
}

printf '0\n' >"$submit_param"
printf '0\n' >"$agg_submit_param"
printf '0\n' >"$completion_param"
mesh_valid && traffic_valid && paths_valid || {
	echo "baseline mesh validation failed" >&2
	exit 1
}

start_epoch=$(date +%s)
drive_phase submission "$submit_param" || exit 1
# Reset the printk ratelimit window so each phase retains evidence.
sleep 6
drive_phase aggregate-submission "$agg_submit_param" \
	'test: rejecting aggregate USB TX' || exit 1
sleep 6
drive_phase completion "$completion_param" \
	'test: reported injected USB TX completion error' || exit 1
traffic_valid && mesh_valid && paths_valid || {
	echo "post-injection mesh validation failed" >&2
	exit 1
}

journalctl -k --since "@$start_epoch" --no-pager >"$kernel_log" 2>&1
tx_events=$(grep 'USB TX URB error -71' "$kernel_log" || true)
unexpected=$(grep -Ei 'error -71|EPROTO|over.?current|under.?voltage|usb .*disconnect|usb .*reset|recoverable RX URB|transient RX URB submit error|USB TX URB error|read register .* (recovered|failed)|write register .* failed' \
	"$kernel_log" | grep -v 'USB TX URB error -71' || true)
counter_values_valid=$(printf '%s\n' "$tx_events" | awk '
	match($0, /errors=[0-9]+/) {
		prefix = substr($0, 1, RSTART - 1);
		kernel_at = index(prefix, "kernel: ");
		if (kernel_at)
			prefix = substr(prefix, kernel_at + 8);
		sub(/USB TX URB error -71, $/, "", prefix);
		value = substr($0, RSTART + 7, RLENGTH - 7) + 0;
		if (value <= 0 || values[prefix SUBSEP value]++) bad = 1;
		seen++;
	}
	END { print (seen > 0 && !bad ? 1 : 0) }
')
event_count=$(printf '%s\n' "$tx_events" | sed '/^$/d' | awk 'END { print NR + 0 }')
aggregate_events=$(grep -c 'test: rejecting aggregate USB TX' "$kernel_log" || true)
aggregate_cleanups=$(grep -c 'test: cleaned rejected aggregate USB TX' \
	"$kernel_log" || true)
completion_reports=$(grep -c \
	'test: reported injected USB TX completion error' "$kernel_log" || true)
aggregate_cleanup_values_valid=$(grep 'test: cleaned rejected aggregate USB TX' \
	"$kernel_log" | awk '
	match($0, /originals=[0-9]+/) {
		value = substr($0, RSTART + 10, RLENGTH - 10) + 0;
		if (value < 2) bad = 1;
		seen++;
	}
	END { print (seen > 0 && !bad ? 1 : 0) }
')
unexpected_count=$(printf '%s\n' "$unexpected" | sed '/^$/d' |
	awk 'END { print NR + 0 }')
printf 'result=complete tx_diagnostics=%s aggregate_rejections=%s aggregate_cleanups=%s completion_reports=%s aggregate_cleanup_values_valid=%s counter_values_valid=%s unexpected_events=%s root_paths=%s peer_paths=%s\n' \
	"$event_count" "$aggregate_events" "$aggregate_cleanups" \
	"$completion_reports" "$aggregate_cleanup_values_valid" "$counter_values_valid" \
	"$unexpected_count" "$root_paths" "$peer_paths"
printf '%s\n' "$unexpected" | sed '/^$/d'

[ "$event_count" -ge 3 ] && [ "$aggregate_events" -eq "$FAILURES" ] &&
	[ "$aggregate_cleanups" -eq "$FAILURES" ] &&
	[ "$completion_reports" -eq "$FAILURES" ] &&
	[ "$aggregate_cleanup_values_valid" -eq 1 ] &&
	[ "$counter_values_valid" -eq 1 ] &&
	[ "$unexpected_count" -eq 0 ]
