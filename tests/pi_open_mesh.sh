#!/bin/sh
# Normalize and join the two-radio open 802.11s hardware-in-loop topology.

set -eu

IW=${IW:-/usr/sbin/iw}
ROOT_IF=${ROOT_IF:-wlan2}
PEER_IF=${PEER_IF:-wlan1}
PEER_NS=${PEER_NS:-meshpeer}
ROOT_MAC=${ROOT_MAC:-fc:22:1c:30:08:c1}
PEER_MAC=${PEER_MAC:-1c:bf:ce:f3:78:4d}
ROOT_IP=${ROOT_IP:-10.44.0.1}
PEER_IP=${PEER_IP:-10.44.0.2}
MESH_ID=${MESH_ID:-overnight-mesh}
FREQ=${FREQ:-2412}
WIDTH=${WIDTH:-HT20}
LOCK_FILE=${LOCK_FILE:-/run/lock/rtw88-mesh-test.lock}

if command -v flock >/dev/null 2>&1; then
	exec 9>"$LOCK_FILE"
	if ! flock -n 9; then
		echo "another rtw88 mesh test holds $LOCK_FILE" >&2
		exit 75
	fi
fi

ns()
{
	ip netns exec "$PEER_NS" "$@"
}

find_interface()
{
	ip -o link | awk -v mac="$1" \
	'tolower($0) ~ tolower(mac) { sub(":", "", $2); print $2; exit }'
}

if ! ip netns list | awk '{ print $1 }' | grep -qx "$PEER_NS"; then
	ip netns add "$PEER_NS"
fi

current_peer=$(ns ip -o link | awk -v mac="$PEER_MAC" \
	'tolower($0) ~ tolower(mac) { sub(":", "", $2); print $2; exit }')
if [ -z "$current_peer" ]; then
	current_peer=$(find_interface "$PEER_MAC")
	if [ -z "$current_peer" ]; then
		echo "peer interface with MAC $PEER_MAC not found" >&2
		exit 1
	fi

	nmcli device set "$current_peer" managed no >/dev/null 2>&1 || true
	ip link set "$current_peer" down
	peer_wiphy=$($IW dev "$current_peer" info |
		awk '$1 == "wiphy" { print $2; exit }')
	if [ -z "$peer_wiphy" ]; then
		echo "could not resolve peer wiphy" >&2
		exit 1
	fi
	$IW phy "phy$peer_wiphy" set netns name "$PEER_NS"
	current_peer=$(ns ip -o link | awk -v mac="$PEER_MAC" \
		'tolower($0) ~ tolower(mac) { sub(":", "", $2); print $2; exit }')
fi

if [ -z "$current_peer" ]; then
	echo "peer interface did not appear in $PEER_NS" >&2
	exit 1
fi

ns ip link set "$current_peer" down
if [ "$current_peer" != "$PEER_IF" ]; then
	ns ip link set "$current_peer" name "$PEER_IF"
fi
ns ip link set lo up

current_root=$(find_interface "$ROOT_MAC")
if [ -z "$current_root" ]; then
	echo "RTL8812AU interface with MAC $ROOT_MAC not found" >&2
	exit 1
fi

nmcli device set "$current_root" managed no >/dev/null 2>&1 || true
$IW dev "$current_root" mesh leave 2>/dev/null || true
ip link set "$current_root" down
if [ "$current_root" != "$ROOT_IF" ]; then
	ip link set "$current_root" name "$ROOT_IF"
fi
$IW dev "$ROOT_IF" set type mesh

ns $IW dev "$PEER_IF" mesh leave 2>/dev/null || true
ns ip link set "$PEER_IF" down
ns $IW dev "$PEER_IF" set type mesh

ip link set "$ROOT_IF" up
ns ip link set "$PEER_IF" up
ns $IW dev "$PEER_IF" mesh join "$MESH_ID" freq "$FREQ" "$WIDTH"
$IW dev "$ROOT_IF" mesh join "$MESH_ID" freq "$FREQ" "$WIDTH"

ip addr flush dev "$ROOT_IF"
ip addr add "$ROOT_IP/24" dev "$ROOT_IF"
ns ip addr flush dev "$PEER_IF"
ns ip addr add "$PEER_IP/24" dev "$PEER_IF"

poll=0
while [ "$poll" -lt 100 ]; do
	if $IW dev "$ROOT_IF" station dump |
		grep -q 'mesh plink:[[:space:]]*ESTAB' &&
		ns $IW dev "$PEER_IF" station dump |
		grep -q 'mesh plink:[[:space:]]*ESTAB'; then
		echo "mesh established after $poll poll(s)"
		exit 0
	fi
	poll=$((poll + 1))
	sleep 0.1
done

echo "open mesh did not establish within 10 seconds" >&2
exit 1
