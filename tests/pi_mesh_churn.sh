#!/bin/sh
# Repeated two-radio 802.11s leave/join and cold-path validation on the Pi.
# Run as root after placing PEER_IF in PEER_NS and configuring both interfaces
# as mesh points. The management connection must not use either test radio.

set -eu

LOCK_FILE=${LOCK_FILE:-/run/lock/rtw88-mesh-test.lock}
command -v flock >/dev/null 2>&1 || { echo "flock is required" >&2; exit 2; }
exec 9>"$LOCK_FILE"
if ! flock -n 9; then
	echo "another rtw88 mesh test holds $LOCK_FILE" >&2
	exit 75
fi

IW=${IW:-/usr/sbin/iw}
ROOT_IF=${ROOT_IF:-}
PEER_IF=${PEER_IF:-}
PEER_NS=${PEER_NS:-meshpeer}
MESH_ID=${MESH_ID:-overnight-mesh}
FREQ=${FREQ:-2412}
WIDTH=${WIDTH:-HT20}
ROOT_IP=${ROOT_IP:-10.44.0.1}
PEER_IP=${PEER_IP:-10.44.0.2}
ROOT_MAC=${ROOT_MAC:?set ROOT_MAC to the primary adapter MAC}
PEER_MAC=${PEER_MAC:?set PEER_MAC to the peer adapter MAC}
CYCLES=${CYCLES:-20}
ESTAB_POLLS=${ESTAB_POLLS:-100}
ROOT_DRIVER=${ROOT_DRIVER:-rtw_8812au}
PEER_DRIVER=${PEER_DRIVER:-}

ns()
{
	ip netns exec "$PEER_NS" "$@"
}

if [ -z "$ROOT_IF" ]; then
	for netdev in /sys/class/net/*; do
		if [ "$(cat "$netdev/address")" = "$ROOT_MAC" ]; then
			ROOT_IF=${netdev##*/}
			break
		fi
	done
fi

if [ -z "$ROOT_IF" ]; then
	echo "cannot find root mesh radio with MAC $ROOT_MAC" >&2
	exit 1
fi

if [ -z "$PEER_IF" ]; then
	PEER_IF=$(ip netns exec "$PEER_NS" ip -o link 2>/dev/null |
		awk -v mac="$PEER_MAC" '
			tolower($0) ~ tolower(mac) {
				sub(/:$/, "", $2); print $2; exit
			}
		')
fi

if [ -z "$PEER_IF" ]; then
	echo "cannot find peer mesh radio with MAC $PEER_MAC in $PEER_NS" >&2
	exit 1
fi

root_driver=$(basename "$(readlink "/sys/class/net/$ROOT_IF/device/driver")")
peer_driver=$(ip netns exec "$PEER_NS" basename \
	"$(ip netns exec "$PEER_NS" readlink "/sys/class/net/$PEER_IF/device/driver")")
if [ "$root_driver" != "$ROOT_DRIVER" ]; then
	echo "root driver is $root_driver, expected $ROOT_DRIVER" >&2
	exit 2
fi
if [ -n "$PEER_DRIVER" ] && [ "$peer_driver" != "$PEER_DRIVER" ]; then
	echo "peer driver is $peer_driver, expected $PEER_DRIVER" >&2
	exit 2
fi

case $CYCLES in
	*[!0-9]*|''|0) echo "CYCLES must be a positive integer" >&2; exit 2 ;;
esac

is_established()
{
	$IW dev "$ROOT_IF" station dump |
		grep -q 'mesh plink:[[:space:]]*ESTAB' &&
		ns $IW dev "$PEER_IF" station dump |
		grep -q 'mesh plink:[[:space:]]*ESTAB'
}

clear_paths()
{
	$IW dev "$ROOT_IF" mpath del "$PEER_MAC" 2>/dev/null || true
	ns $IW dev "$PEER_IF" mpath del "$ROOT_MAC" 2>/dev/null || true
	ip neigh flush dev "$ROOT_IF" >/dev/null 2>&1 || true
	ns ip neigh flush dev "$PEER_IF" >/dev/null 2>&1 || true
}

join_cycle()
{
	$IW dev "$ROOT_IF" mesh leave 2>/dev/null || true
	ns $IW dev "$PEER_IF" mesh leave 2>/dev/null || true
	ip link set "$ROOT_IF" down
	ns ip link set "$PEER_IF" down
	sleep 1
	ip link set "$ROOT_IF" up
	ns ip link set "$PEER_IF" up
	if ! ns $IW dev "$PEER_IF" mesh join "$MESH_ID" freq "$FREQ" "$WIDTH"; then
		echo PEER_JOIN_FAIL
		return 1
	fi
	if ! $IW dev "$ROOT_IF" mesh join "$MESH_ID" freq "$FREQ" "$WIDTH"; then
		echo ROOT_JOIN_FAIL
		return 1
	fi
}

start_epoch=$(date +%s)
pass_root=0
pass_peer=0
pass_root_mcast=0
pass_peer_mcast=0
pass_paths=0
plink_fail=0
join_fail=0

printf '# mesh-churn start=%s cycles=%s root=%s peer=%s mesh=%s freq=%s width=%s\n' \
	"$(date --iso-8601=seconds)" "$CYCLES" "$ROOT_IF" "$PEER_IF" \
	"$MESH_ID" "$FREQ" "$WIDTH"
printf 'cycle plink_ms root_first_contact peer_first_contact root_multicast peer_multicast root_paths peer_paths\n'

cycle=1
while [ "$cycle" -le "$CYCLES" ]; do
	if ! join_result=$(join_cycle); then
		join_fail=$((join_fail + 1))
		printf '%s 0 %s %s %s %s 0 0\n' "$cycle" "$join_result" \
			"$join_result" "$join_result" "$join_result"
		cycle=$((cycle + 1))
		continue
	fi
	t0=$(date +%s%3N)
	poll=0
	while ! is_established; do
		poll=$((poll + 1))
		if [ "$poll" -ge "$ESTAB_POLLS" ]; then
			break
		fi
		sleep 0.1
	done
	t1=$(date +%s%3N)
	plink_ms=$((t1 - t0))

	if ! is_established; then
		plink_fail=$((plink_fail + 1))
		printf '%s %s PLINK_FAIL PLINK_FAIL PLINK_FAIL PLINK_FAIL 0 0\n' \
			"$cycle" "$plink_ms"
		cycle=$((cycle + 1))
		continue
	fi

	clear_paths
	if ping -I "$ROOT_IF" -c 1 -W 2 "$PEER_IP" >/dev/null 2>&1; then
		root_result=PASS
		pass_root=$((pass_root + 1))
	else
		root_result=FAIL
	fi

	clear_paths
	if ns ping -I "$PEER_IF" -c 1 -W 2 "$ROOT_IP" >/dev/null 2>&1; then
		peer_result=PASS
		pass_peer=$((pass_peer + 1))
	else
		peer_result=FAIL
	fi

	# Observe reachability in the receiving namespace.  Multicast is not
	# acknowledged at 802.11, so use a short three-frame burst rather than
	# turning one ordinary lost group frame into a churn failure.  The separate
	# multicast probe measures loss over hundreds of sender-captured frames.
	# -p avoids changing the mac80211 promiscuous filter while the test runs.
	(exec 9>&-; ns timeout 3 tcpdump -p -qn -i "$PEER_IF" -c 1 \
		"ether src $ROOT_MAC and icmp and dst 224.0.0.1" \
		>/dev/null 2>&1) &
	capture_pid=$!
	sleep 0.2
	ping -I "$ROOT_IF" -c 3 -i 0.05 -W 1 224.0.0.1 >/dev/null 2>&1 || true
	if wait "$capture_pid"; then
		root_mcast=PASS
		pass_root_mcast=$((pass_root_mcast + 1))
	else
		root_mcast=FAIL
	fi

	(exec 9>&-; timeout 3 tcpdump -p -qn -i "$ROOT_IF" -c 1 \
		"ether src $PEER_MAC and icmp and dst 224.0.0.1" \
		>/dev/null 2>&1) &
	capture_pid=$!
	sleep 0.2
	ns ping -I "$PEER_IF" -c 3 -i 0.05 -W 1 224.0.0.1 >/dev/null 2>&1 || true
	if wait "$capture_pid"; then
		peer_mcast=PASS
		pass_peer_mcast=$((pass_peer_mcast + 1))
	else
		peer_mcast=FAIL
	fi

	root_paths=$($IW dev "$ROOT_IF" mpath dump | awk 'NR > 1 { n++ } END { print n + 0 }')
	peer_paths=$(ns $IW dev "$PEER_IF" mpath dump | awk 'NR > 1 { n++ } END { print n + 0 }')
	if [ "$root_paths" -gt 0 ] && [ "$peer_paths" -gt 0 ]; then
		pass_paths=$((pass_paths + 1))
	fi
	printf '%s %s %s %s %s %s %s %s\n' "$cycle" "$plink_ms" \
		"$root_result" "$peer_result" "$root_mcast" "$peer_mcast" \
		"$root_paths" "$peer_paths"
	cycle=$((cycle + 1))
done

printf '# summary join_pass=%s/%s plink_pass=%s/%s root_first_contact=%s/%s peer_first_contact=%s/%s root_multicast=%s/%s peer_multicast=%s/%s paths_both=%s/%s elapsed_s=%s\n' \
	"$((CYCLES - join_fail))" "$CYCLES" \
	"$((CYCLES - join_fail - plink_fail))" "$CYCLES" \
	"$pass_root" "$CYCLES" \
	"$pass_peer" "$CYCLES" "$pass_root_mcast" "$CYCLES" \
	"$pass_peer_mcast" "$CYCLES" "$pass_paths" "$CYCLES" \
	"$(( $(date +%s) - start_epoch ))"
printf '# usb-errors-since-start\n'
kernel_events=$(journalctl -k --since "@$start_epoch" --no-pager 2>/dev/null |
	grep -Ei 'over.?current|under.?voltage|error -71|EPROTO|usb .*disconnect|usb .*reset|recoverable RX URB|transient RX URB submit error|USB TX URB error|read register .* (recovered|failed)|write register .* failed' || true)
printf '%s\n' "$kernel_events" | sed '/^$/d'
kernel_event_count=$(printf '%s\n' "$kernel_events" | sed '/^$/d' |
	awk 'END { print NR + 0 }')

functional_failure=0
if [ "$join_fail" -ne 0 ] || [ "$plink_fail" -ne 0 ] ||
   [ "$pass_root" -ne "$CYCLES" ] || [ "$pass_peer" -ne "$CYCLES" ] ||
   [ "$pass_root_mcast" -ne "$CYCLES" ] ||
   [ "$pass_peer_mcast" -ne "$CYCLES" ] ||
   [ "$pass_paths" -ne "$CYCLES" ]; then
	functional_failure=1
fi
if [ "$kernel_event_count" -ne 0 ]; then
	echo "# result=transport-event-review-required functional_failure=$functional_failure kernel_events=$kernel_event_count"
	exit 4
fi
[ "$functional_failure" -eq 0 ]
