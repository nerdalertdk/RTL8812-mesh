#!/bin/sh
# Validate open 802.11s operation across a caller-selected channel/width profile.

set -eu

IW=${IW:-/usr/sbin/iw}
ROOT_MAC=${ROOT_MAC:?set ROOT_MAC to the primary adapter MAC}
PEER_MAC=${PEER_MAC:?set PEER_MAC to the peer adapter MAC}
PEER_NS=${PEER_NS:-meshpeer}
ROOT_IP=${ROOT_IP:-10.44.0.1}
PEER_IP=${PEER_IP:-10.44.0.2}
MESH_ID=${MESH_ID:-overnight-mesh}
WIDTH=${WIDTH:-HT20}
CHANNELS=${CHANNELS:-1:2412 2:2417 3:2422 4:2427 5:2432 6:2437 7:2442 8:2447 9:2452 10:2457 11:2462 12:2467 13:2472}
RESTORE_FREQ=${RESTORE_FREQ:-2412}
LOCK_FILE=${LOCK_FILE:-/run/lock/rtw88-mesh-test.lock}
ESTAB_POLLS=${ESTAB_POLLS:-100}
MULTICAST_COUNT=${MULTICAST_COUNT:-3}
ROOT_DRIVER=${ROOT_DRIVER:-rtw_8812au}
PEER_DRIVER=${PEER_DRIVER:-}

command -v flock >/dev/null 2>&1 || { echo "flock is required" >&2; exit 2; }
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

is_established()
{
	$IW dev "$ROOT_IF" station dump 2>/dev/null |
		grep -q 'mesh plink:[[:space:]]*ESTAB' &&
		ns $IW dev "$PEER_IF" station dump 2>/dev/null |
		grep -q 'mesh plink:[[:space:]]*ESTAB'
}

join_frequency()
{
	freq=$1

	$IW dev "$ROOT_IF" mesh leave 2>/dev/null || true
	ns $IW dev "$PEER_IF" mesh leave 2>/dev/null || true
	ip link set "$ROOT_IF" down
	ns ip link set "$PEER_IF" down
	$IW dev "$ROOT_IF" set type mesh
	ns $IW dev "$PEER_IF" set type mesh
	ip link set "$ROOT_IF" up
	ns ip link set "$PEER_IF" up
	ns $IW dev "$PEER_IF" mesh join "$MESH_ID" freq "$freq" "$WIDTH"
	$IW dev "$ROOT_IF" mesh join "$MESH_ID" freq "$freq" "$WIDTH"

	ip addr replace "$ROOT_IP/24" dev "$ROOT_IF"
	ns ip addr replace "$PEER_IP/24" dev "$PEER_IF"
}

restore_default()
{
	trap - EXIT INT TERM
	join_frequency "$RESTORE_FREQ" >/dev/null 2>&1 || true
}

trap restore_default EXIT
trap 'restore_default; exit 130' INT TERM

start_epoch=$(date +%s)
pass=0
total=0
printf '# mesh-channel-sweep start=%s root=%s peer=%s width=%s restore_freq=%s\n' \
	"$(date --iso-8601=seconds)" "$ROOT_IF" "$PEER_IF" "$WIDTH" \
	"$RESTORE_FREQ"
printf 'channel frequency plink_ms root_contact peer_contact root_multicast peer_multicast root_paths peer_paths result\n'

for entry in $CHANNELS; do
	channel=${entry%%:*}
	freq=${entry#*:}
	total=$((total + 1))
	result=PASS
	root_contact=PASS
	peer_contact=PASS
	root_multicast=PASS
	peer_multicast=PASS
	root_paths=0
	peer_paths=0

	t0=$(date +%s%3N)
	if ! join_frequency "$freq"; then
		printf '%s %s 0 JOIN_FAIL JOIN_FAIL JOIN_FAIL JOIN_FAIL 0 0 FAIL\n' \
			"$channel" "$freq"
		continue
	fi
	poll=0
	while ! is_established; do
		poll=$((poll + 1))
		if [ "$poll" -ge "$ESTAB_POLLS" ]; then
			result=FAIL
			break
		fi
		sleep 0.1
	done
	plink_ms=$(( $(date +%s%3N) - t0 ))

	$IW dev "$ROOT_IF" mpath del "$PEER_MAC" 2>/dev/null || true
	ns $IW dev "$PEER_IF" mpath del "$ROOT_MAC" 2>/dev/null || true
	ip neigh flush dev "$ROOT_IF" >/dev/null 2>&1 || true
	ns ip neigh flush dev "$PEER_IF" >/dev/null 2>&1 || true
	if ! ping -I "$ROOT_IF" -c 3 -W 2 "$PEER_IP" >/dev/null 2>&1; then
		root_contact=FAIL
		result=FAIL
	fi
	if ! ns ping -I "$PEER_IF" -c 3 -W 2 "$ROOT_IP" >/dev/null 2>&1; then
		peer_contact=FAIL
		result=FAIL
	fi
	(exec 9>&-; ns timeout 3 tcpdump -p -qn -i "$PEER_IF" -c 1 \
		"ether src $ROOT_MAC and icmp and dst 224.0.0.1" \
		>/dev/null 2>&1) &
	capture_pid=$!
	sleep 0.2
	ping -I "$ROOT_IF" -c "$MULTICAST_COUNT" -i 0.1 -W 1 224.0.0.1 \
		>/dev/null 2>&1 || true
	if ! wait "$capture_pid"; then
		root_multicast=FAIL
		result=FAIL
	fi
	(exec 9>&-; timeout 3 tcpdump -p -qn -i "$ROOT_IF" -c 1 \
		"ether src $PEER_MAC and icmp and dst 224.0.0.1" \
		>/dev/null 2>&1) &
	capture_pid=$!
	sleep 0.2
	ns ping -I "$PEER_IF" -c "$MULTICAST_COUNT" -i 0.1 -W 1 224.0.0.1 \
		>/dev/null 2>&1 || true
	if ! wait "$capture_pid"; then
		peer_multicast=FAIL
		result=FAIL
	fi
	root_paths=$($IW dev "$ROOT_IF" mpath dump 2>/dev/null |
		awk 'NR > 1 { n++ } END { print n + 0 }')
	peer_paths=$(ns $IW dev "$PEER_IF" mpath dump 2>/dev/null |
		awk 'NR > 1 { n++ } END { print n + 0 }')
	if [ "$root_paths" -eq 0 ] || [ "$peer_paths" -eq 0 ]; then
		result=FAIL
	fi
	[ "$result" = PASS ] && pass=$((pass + 1))
	printf '%s %s %s %s %s %s %s %s %s %s\n' "$channel" "$freq" \
		"$plink_ms" "$root_contact" "$peer_contact" "$root_multicast" \
		"$peer_multicast" "$root_paths" "$peer_paths" "$result"
done

restore_default
printf '# summary channels_pass=%s/%s elapsed_s=%s\n' "$pass" "$total" \
	"$(( $(date +%s) - start_epoch ))"
printf '# usb-errors-since-start\n'
kernel_events=$(journalctl -k --since "@$start_epoch" --no-pager 2>/dev/null |
	grep -Ei 'over.?current|under.?voltage|error -71|EPROTO|usb .*disconnect|usb .*reset|recoverable RX URB|transient RX URB submit error|USB TX URB error|read register .* (recovered|failed)|write register .* failed' || true)
printf '%s\n' "$kernel_events" | sed '/^$/d'
kernel_event_count=$(printf '%s\n' "$kernel_events" | sed '/^$/d' |
	awk 'END { print NR + 0 }')

if [ "$kernel_event_count" -ne 0 ]; then
	echo "# result=transport-event-review-required channels_pass=$pass/$total kernel_events=$kernel_event_count"
	exit 4
fi
[ "$pass" -eq "$total" ]
