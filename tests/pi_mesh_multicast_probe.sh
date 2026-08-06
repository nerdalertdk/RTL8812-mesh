#!/bin/sh
# Quantify multicast delivery in each direction without changing mesh topology.

set -eu

IW=${IW:-/usr/sbin/iw}
ROOT_MAC=${ROOT_MAC:?set ROOT_MAC to the primary adapter MAC}
PEER_MAC=${PEER_MAC:?set PEER_MAC to the peer adapter MAC}
PEER_NS=${PEER_NS:-meshpeer}
ROOT_IP=${ROOT_IP:-10.44.0.1}
PEER_IP=${PEER_IP:-10.44.0.2}
GROUP=${GROUP:-224.0.0.1}
GROUP_MAC=${GROUP_MAC:-01:00:5e:00:00:01}
ROUNDS=${ROUNDS:-20}
PACKETS=${PACKETS:-20}
INTERVAL=${INTERVAL:-0.05}
CAPTURE_TIMEOUT=${CAPTURE_TIMEOUT:-4}
LOCK_FILE=${LOCK_FILE:-/run/lock/rtw88-mesh-test.lock}
LOG_DIR=${LOG_DIR:-/var/tmp/rtl8812au-mesh/mesh-multicast-probe}
MIN_DELIVERY_PERCENT=${MIN_DELIVERY_PERCENT:-99}
ROOT_DRIVER=${ROOT_DRIVER:-rtw_8812au}
PEER_DRIVER=${PEER_DRIVER:-}

for value in "$ROUNDS" "$PACKETS" "$CAPTURE_TIMEOUT" "$MIN_DELIVERY_PERCENT"; do
	case $value in *[!0-9]*|''|0) echo "rounds, packets, timeout, and threshold must be positive integers" >&2; exit 2 ;; esac
done
[ "$MIN_DELIVERY_PERCENT" -le 100 ] || { echo "MIN_DELIVERY_PERCENT must be <= 100" >&2; exit 2; }

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

capture_root()
{
	output=$1
	source=$2
	(exec 9>&-; timeout "$CAPTURE_TIMEOUT" tcpdump -l -pqn -c "$PACKETS" \
		-i "$ROOT_IF" \
		"ether src $source and ether dst $GROUP_MAC and icmp" \
		>"$output" 2>/dev/null) &
	CAPTURE_PID=$!
}

capture_peer()
{
	output=$1
	source=$2
	(exec 9>&-; ns timeout "$CAPTURE_TIMEOUT" tcpdump -l -pqn -c "$PACKETS" \
		-i "$PEER_IF" \
		"ether src $source and ether dst $GROUP_MAC and icmp" \
		>"$output" 2>/dev/null) &
	CAPTURE_PID=$!
}

wait_capture()
{
	pid=$1
	wait "$pid" 2>/dev/null || true
}

count_packets()
{
	awk 'END { print NR + 0 }' "$1"
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

if ! $IW dev "$ROOT_IF" station dump | grep -q 'mesh plink:[[:space:]]*ESTAB' ||
   ! ns $IW dev "$PEER_IF" station dump | grep -q 'mesh plink:[[:space:]]*ESTAB'; then
	echo "mesh peer link is not established in both directions" >&2
	exit 1
fi

mkdir -p "$LOG_DIR"
start_epoch=$(date +%s)
run_id=$(date -u +%Y%m%dT%H%M%SZ)
result=$LOG_DIR/multicast-$run_id.log
tmp_dir=$(mktemp -d /tmp/rtw88-multicast-probe-XXXXXX)
trap 'rm -rf -- "$tmp_dir"' EXIT INT TERM

root_info=$($IW dev "$ROOT_IF" info | awk '/wiphy|channel/ { printf "%s ", $0 }')
peer_info=$(ns $IW dev "$PEER_IF" info | awk '/wiphy|channel/ { printf "%s ", $0 }')
printf '# multicast-probe start=%s rounds=%s packets=%s group=%s root=%s peer=%s\n' \
	"$(date --iso-8601=seconds)" "$ROUNDS" "$PACKETS" "$GROUP" \
	"$ROOT_IF" "$PEER_IF" | tee "$result"
printf '# root_info=%s\n# peer_info=%s\n' "$root_info" "$peer_info" |
	tee -a "$result"
printf 'round direction sender_seen receiver_seen lost_after_sender\n' |
	tee -a "$result"

root_sender_total=0
root_receiver_total=0
peer_sender_total=0
peer_receiver_total=0
round=1
while [ "$round" -le "$ROUNDS" ]; do
	root_sender=$tmp_dir/root-sender-$round
	peer_receiver=$tmp_dir/peer-receiver-$round
	capture_root "$root_sender" "$ROOT_MAC"
	root_capture_pid=$CAPTURE_PID
	capture_peer "$peer_receiver" "$ROOT_MAC"
	peer_capture_pid=$CAPTURE_PID
	sleep 0.3
	ping -I "$ROOT_IF" -c "$PACKETS" -i "$INTERVAL" -W 1 "$GROUP" \
		>/dev/null 2>&1 || true
	wait_capture "$root_capture_pid"
	wait_capture "$peer_capture_pid"
	sender_seen=$(count_packets "$root_sender")
	receiver_seen=$(count_packets "$peer_receiver")
	lost=$((sender_seen - receiver_seen))
	[ "$lost" -ge 0 ] || lost=0
	root_sender_total=$((root_sender_total + sender_seen))
	root_receiver_total=$((root_receiver_total + receiver_seen))
	printf '%s root-to-peer %s %s %s\n' "$round" "$sender_seen" \
		"$receiver_seen" "$lost" | tee -a "$result"

	peer_sender=$tmp_dir/peer-sender-$round
	root_receiver=$tmp_dir/root-receiver-$round
	capture_peer "$peer_sender" "$PEER_MAC"
	peer_capture_pid=$CAPTURE_PID
	capture_root "$root_receiver" "$PEER_MAC"
	root_capture_pid=$CAPTURE_PID
	sleep 0.3
	ns ping -I "$PEER_IF" -c "$PACKETS" -i "$INTERVAL" -W 1 "$GROUP" \
		>/dev/null 2>&1 || true
	wait_capture "$peer_capture_pid"
	wait_capture "$root_capture_pid"
	sender_seen=$(count_packets "$peer_sender")
	receiver_seen=$(count_packets "$root_receiver")
	lost=$((sender_seen - receiver_seen))
	[ "$lost" -ge 0 ] || lost=0
	peer_sender_total=$((peer_sender_total + sender_seen))
	peer_receiver_total=$((peer_receiver_total + receiver_seen))
	printf '%s peer-to-root %s %s %s\n' "$round" "$sender_seen" \
		"$receiver_seen" "$lost" | tee -a "$result"

	round=$((round + 1))
done

printf '# summary root_sender=%s peer_received=%s peer_sender=%s root_received=%s\n' \
	"$root_sender_total" "$root_receiver_total" "$peer_sender_total" \
	"$peer_receiver_total" | tee -a "$result"
printf '# kernel-transport-events-since-start\n' | tee -a "$result"
kernel_events=$(journalctl -k --since "@$start_epoch" --no-pager 2>/dev/null |
	grep -Ei 'error -71|EPROTO|over.?current|usb .*disconnect|usb .*reset|recoverable RX URB|transient RX URB submit error|USB TX URB error|read register .* (recovered|failed)|write register .* failed' || true)
printf '%s\n' "$kernel_events" | sed '/^$/d' | tee -a "$result"
kernel_event_count=$(printf '%s\n' "$kernel_events" | sed '/^$/d' | awk 'END { print NR + 0 }')

expected=$((ROUNDS * PACKETS))
classification=pass
status=0
if [ "$kernel_event_count" -ne 0 ]; then
	if [ "$root_sender_total" -ne "$expected" ] ||
	   [ "$peer_sender_total" -ne "$expected" ]; then
		classification=transport-event-with-incomplete-sender-capture
	elif [ $((root_receiver_total * 100)) -lt $((root_sender_total * MIN_DELIVERY_PERCENT)) ] ||
	     [ $((peer_receiver_total * 100)) -lt $((peer_sender_total * MIN_DELIVERY_PERCENT)) ]; then
		classification=transport-event-with-delivery-failure
	else
		classification=recovered-transport-event-review-required
	fi
	status=4
elif [ "$root_sender_total" -ne "$expected" ] ||
   [ "$peer_sender_total" -ne "$expected" ]; then
	classification=invalid-incomplete-sender-capture
	status=2
elif [ $((root_receiver_total * 100)) -lt $((root_sender_total * MIN_DELIVERY_PERCENT)) ] ||
     [ $((peer_receiver_total * 100)) -lt $((peer_sender_total * MIN_DELIVERY_PERCENT)) ]; then
	classification=delivery-below-threshold
	status=1
fi
printf '# result classification=%s minimum_delivery_percent=%s expected_sender=%s kernel_events=%s\n' \
	"$classification" "$MIN_DELIVERY_PERCENT" "$expected" "$kernel_event_count" |
	tee -a "$result"
exit "$status"
