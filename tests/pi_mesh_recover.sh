#!/bin/sh
# Reconstruct the two-radio Pi mesh after USB re-enumeration or netdev rename.

set -eu

IW=${IW:-/usr/sbin/iw}
ROOT_MAC=${ROOT_MAC:?set ROOT_MAC to the primary adapter MAC}
PEER_MAC=${PEER_MAC:?set PEER_MAC to the peer adapter MAC}
PEER_NS=${PEER_NS:-meshpeer}
MESH_ID=${MESH_ID:-overnight-mesh}
FREQ=${FREQ:-2412}
WIDTH=${WIDTH:-HT20}
ROOT_ADDR=${ROOT_ADDR:-10.44.0.1/24}
PEER_ADDR=${PEER_ADDR:-10.44.0.2/24}
DEVICE_POLLS=${DEVICE_POLLS:-60}
ESTAB_POLLS=${ESTAB_POLLS:-100}
LOCK_FILE=${LOCK_FILE:-/run/lock/rtw88-mesh-test.lock}
LOCK_WAIT=${LOCK_WAIT:-90}

if command -v flock >/dev/null 2>&1; then
	exec 9>"$LOCK_FILE"
	if ! flock -w "$LOCK_WAIT" 9; then
		echo "timed out waiting ${LOCK_WAIT}s for $LOCK_FILE" >&2
		exit 75
	fi
fi

find_root_if()
{
	ip -o link | awk -v mac="$1" '
		tolower($0) ~ tolower(mac) { sub(/:$/, "", $2); print $2; exit }
	'
}

find_peer_if()
{
	ip netns exec "$PEER_NS" ip -o link 2>/dev/null | awk -v mac="$1" '
		tolower($0) ~ tolower(mac) { sub(/:$/, "", $2); print $2; exit }
	'
}

ip netns list | awk '{ print $1 }' | grep -qx "$PEER_NS" ||
	ip netns add "$PEER_NS"

poll=0
while :; do
	root_if=$(find_root_if "$ROOT_MAC")
	peer_if=$(find_peer_if "$PEER_MAC")
	peer_root_if=$(find_root_if "$PEER_MAC")
	if [ -n "$root_if" ] && { [ -n "$peer_if" ] || [ -n "$peer_root_if" ]; }; then
		break
	fi
	poll=$((poll + 1))
	if [ "$poll" -ge "$DEVICE_POLLS" ]; then
		echo "timed out waiting for mesh radios" >&2
		exit 1
	fi
	sleep 1
done

if [ -z "$peer_if" ]; then
	peer_phy=$($IW dev "$peer_root_if" info | awk '/wiphy/ { print "phy" $2 }')
	ip link set "$peer_root_if" down
	$IW phy "$peer_phy" set netns name "$PEER_NS"
	peer_if=$(find_peer_if "$PEER_MAC")
fi

if command -v nmcli >/dev/null 2>&1; then
	nmcli device set "$root_if" managed no 2>/dev/null || true
fi

$IW dev "$root_if" mesh leave 2>/dev/null || true
ip netns exec "$PEER_NS" $IW dev "$peer_if" mesh leave 2>/dev/null || true
ip link set "$root_if" down
ip netns exec "$PEER_NS" ip link set "$peer_if" down
$IW dev "$root_if" set type mesh
ip netns exec "$PEER_NS" $IW dev "$peer_if" set type mesh
ip link set "$root_if" up
ip netns exec "$PEER_NS" ip link set lo up
ip netns exec "$PEER_NS" ip link set "$peer_if" up
$IW dev "$root_if" mesh join "$MESH_ID" freq "$FREQ" "$WIDTH"
ip netns exec "$PEER_NS" $IW dev "$peer_if" mesh join \
	"$MESH_ID" freq "$FREQ" "$WIDTH"
ip addr flush dev "$root_if"
ip addr add "$ROOT_ADDR" dev "$root_if"
ip netns exec "$PEER_NS" ip addr flush dev "$peer_if"
ip netns exec "$PEER_NS" ip addr add "$PEER_ADDR" dev "$peer_if"

poll=0
while :; do
	if $IW dev "$root_if" station dump |
		grep -q 'mesh plink:[[:space:]]*ESTAB' &&
	   ip netns exec "$PEER_NS" $IW dev "$peer_if" station dump |
		grep -q 'mesh plink:[[:space:]]*ESTAB'; then
		break
	fi
	poll=$((poll + 1))
	if [ "$poll" -ge "$ESTAB_POLLS" ]; then
		echo "mesh recovery timed out waiting for peer establishment" >&2
		exit 1
	fi
	sleep 0.1
done

printf 'mesh recovered root=%s peer=%s namespace=%s\n' \
	"$root_if" "$peer_if" "$PEER_NS"
