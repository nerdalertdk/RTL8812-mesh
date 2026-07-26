#!/bin/sh
# Quantify multicast delivery in each direction without changing mesh topology.

set -eu

IW=${IW:-/usr/sbin/iw}
ROOT_MAC=${ROOT_MAC:-fc:22:1c:30:08:c1}
PEER_MAC=${PEER_MAC:-1c:bf:ce:f3:78:4d}
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
LOG_DIR=${LOG_DIR:-/home/msh/mesh-multicast-probe}

if command -v flock >/dev/null 2>&1; then
	exec 9>"$LOCK_FILE"
	if ! flock -n 9; then
		echo "another rtw88 mesh test holds $LOCK_FILE" >&2
		exit 75
	fi
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
journalctl -k --since "@$start_epoch" \
	--no-pager 2>/dev/null |
	grep -Ei 'error -71|EPROTO|over.?current|usb .*disconnect|usb .*reset' |
	tee -a "$result" || true
