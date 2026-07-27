#!/bin/sh
# Stress concurrent RTL8812AU synchronous USB control reads without writes.

set -eu

IW=${IW:-/usr/sbin/iw}
MODINFO=${MODINFO:-/sbin/modinfo}
ROOT_MAC=${ROOT_MAC:?set ROOT_MAC to the primary adapter MAC}
PEER_MAC=${PEER_MAC:?set PEER_MAC to the peer adapter MAC}
PEER_NS=${PEER_NS:-meshpeer}
ROOT_IP=${ROOT_IP:-10.44.0.1}
PEER_IP=${PEER_IP:-10.44.0.2}
ROOT_DRIVER=${ROOT_DRIVER:-rtw_8812au}
PEER_DRIVER=${PEER_DRIVER:-}
LOCK_FILE=${LOCK_FILE:-/run/lock/rtw88-mesh-test.lock}
WORKERS=${WORKERS:-16}
READS_PER_WORKER=${READS_PER_WORKER:-64}
REGISTER=${REGISTER:-5a7}
REGISTER_WIDTH=${REGISTER_WIDTH:-1}

[ "$(id -u)" -eq 0 ] || { echo "run this hardware test as root" >&2; exit 2; }
command -v flock >/dev/null 2>&1 || { echo "flock is required" >&2; exit 2; }
for value in "$WORKERS" "$READS_PER_WORKER"; do
	case $value in *[!0-9]*|''|0) echo "worker and read counts must be positive integers" >&2; exit 2 ;; esac
done
case $REGISTER_WIDTH in 1|2|4) ;; *) echo "REGISTER_WIDTH must be 1, 2, or 4" >&2; exit 2 ;; esac
case $REGISTER in *[!0-9a-fA-F]*|'') echo "REGISTER must be hexadecimal" >&2; exit 2 ;; esac
REGISTER=$(printf '%s' "$REGISTER" | tr 'A-F' 'a-f')
command -v journalctl >/dev/null 2>&1 || { echo "journalctl is required" >&2; exit 2; }
[ -x "$MODINFO" ] || { echo "modinfo is required at $MODINFO" >&2; exit 2; }

exec 9>"$LOCK_FILE"
if ! flock -n 9; then
	echo "another rtw88 mesh test holds $LOCK_FILE" >&2
	exit 75
fi

find_root_if()
{
	ip -o link 2>/dev/null | awk -v mac="$ROOT_MAC" '
		tolower($0) ~ tolower(mac) { sub(/:$/, "", $2); print $2; exit }
	'
}

find_peer_if()
{
	ip netns exec "$PEER_NS" ip -o link 2>/dev/null |
		awk -v mac="$PEER_MAC" '
			tolower($0) ~ tolower(mac) {
				sub(/:$/, "", $2); print $2; exit
			}
		'
}

ns()
{
	ip netns exec "$PEER_NS" "$@"
}

ROOT_IF=$(find_root_if)
PEER_IF=$(find_peer_if)
if [ -z "$ROOT_IF" ] || [ -z "$PEER_IF" ]; then
	echo "mesh interfaces not found root=${ROOT_IF:-none} peer=${PEER_IF:-none}" >&2
	exit 1
fi
root_driver=$(basename "$(readlink "/sys/class/net/$ROOT_IF/device/driver")")
peer_driver=$(ns basename "$(ns readlink "/sys/class/net/$PEER_IF/device/driver")")
if [ "$root_driver" != "$ROOT_DRIVER" ]; then
	echo "root driver is $root_driver, expected $ROOT_DRIVER" >&2
	exit 2
fi
if [ -n "$PEER_DRIVER" ] && [ "$peer_driver" != "$PEER_DRIVER" ]; then
	echo "peer driver is $peer_driver, expected $PEER_DRIVER" >&2
	exit 2
fi
for module in rtw_core rtw_usb rtw_88xxa rtw_8812a rtw_8812au; do
	installed=$($MODINFO -F srcversion "$module" 2>/dev/null || true)
	loaded=$(cat "/sys/module/$module/srcversion" 2>/dev/null || true)
	if [ -z "$installed" ] || [ "$installed" != "$loaded" ]; then
		echo "module provenance mismatch: $module installed=${installed:-unavailable} loaded=${loaded:-unavailable}" >&2
		exit 2
	fi
done
if ! $IW dev "$ROOT_IF" station dump | grep -q 'mesh plink:[[:space:]]*ESTAB' ||
   ! ns $IW dev "$PEER_IF" station dump | grep -q 'mesh plink:[[:space:]]*ESTAB'; then
	echo "mesh peer link is not established in both directions" >&2
	exit 1
fi

wiphy=$($IW dev "$ROOT_IF" info | awk '$1 == "wiphy" { print $2; exit }')
read_reg=/sys/kernel/debug/ieee80211/phy$wiphy/rtw88/read_reg
if [ -z "$wiphy" ] || [ ! -w "$read_reg" ] || [ ! -r "$read_reg" ]; then
	echo "rtw88 debugfs read_reg is unavailable for $ROOT_IF" >&2
	exit 2
fi

tmp_dir=$(mktemp -d /tmp/rtw88-usb-ctrl-stress-XXXXXX)
trap 'rm -rf -- "$tmp_dir"' EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
start_epoch=$(date +%s)
printf '%s %s\n' "$REGISTER" "$REGISTER_WIDTH" >"$read_reg"
baseline=$(cat "$read_reg")
expected_pattern="^reg 0x0*$REGISTER: 0x[0-9a-fA-F]{$((REGISTER_WIDTH * 2))}$"
if ! printf '%s\n' "$baseline" | grep -Eq "$expected_pattern"; then
	echo "unexpected baseline register output: $baseline" >&2
	exit 1
fi

worker=1
pids=
while [ "$worker" -le "$WORKERS" ]; do
	(
		exec 9>&-
		read_no=1
		while [ "$read_no" -le "$READS_PER_WORKER" ]; do
			cat "$read_reg"
			read_no=$((read_no + 1))
		done
	) >"$tmp_dir/worker-$worker.log" &
	pids="$pids $!"
	worker=$((worker + 1))
done

worker_failures=0
for pid in $pids; do
	wait "$pid" || worker_failures=$((worker_failures + 1))
done
expected_reads=$((WORKERS * READS_PER_WORKER))
actual_reads=$(awk 'END { print NR + 0 }' "$tmp_dir"/worker-*.log)
valid_reads=$(cat "$tmp_dir"/worker-*.log | grep -Ec "$expected_pattern" || true)

traffic_failed=0
ping -I "$ROOT_IF" -c 10 -W 1 "$PEER_IP" >/dev/null 2>&1 || traffic_failed=1
ns ping -I "$PEER_IF" -c 10 -W 1 "$ROOT_IP" >/dev/null 2>&1 || traffic_failed=1
root_paths=$($IW dev "$ROOT_IF" mpath dump 2>/dev/null |
	awk 'NR > 1 { count++ } END { print count + 0 }')
peer_paths=$(ns $IW dev "$PEER_IF" mpath dump 2>/dev/null |
	awk 'NR > 1 { count++ } END { print count + 0 }')
[ "$root_paths" -gt 0 ] && [ "$peer_paths" -gt 0 ] || traffic_failed=1

kernel_events=$(journalctl -k --since "@$start_epoch" --no-pager 2>/dev/null |
	grep -Ei 'error -71|EPROTO|over.?current|under.?voltage|usb .*disconnect|usb .*reset|recoverable RX URB|transient RX URB submit error|read register .* (recovered|failed)|write register .* failed' || true)
kernel_event_count=$(printf '%s\n' "$kernel_events" | sed '/^$/d' |
	awk 'END { print NR + 0 }')

printf 'workers=%s reads_per_worker=%s expected_reads=%s actual_reads=%s valid_reads=%s worker_failures=%s root_paths=%s peer_paths=%s traffic_failed=%s kernel_events=%s\n' \
	"$WORKERS" "$READS_PER_WORKER" "$expected_reads" "$actual_reads" \
	"$valid_reads" "$worker_failures" "$root_paths" "$peer_paths" \
	"$traffic_failed" "$kernel_event_count"
printf '%s\n' "$kernel_events" | sed '/^$/d'

if [ "$worker_failures" -ne 0 ] || [ "$actual_reads" -ne "$expected_reads" ] ||
   [ "$valid_reads" -ne "$expected_reads" ] || [ "$traffic_failed" -ne 0 ]; then
	exit 1
fi
[ "$kernel_event_count" -eq 0 ] || exit 4
exit 0
