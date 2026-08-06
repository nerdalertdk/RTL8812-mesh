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
ROOT_DRIVER=${ROOT_DRIVER:-rtw_8812au}
PEER_DRIVER=${PEER_DRIVER:-}
PING_COUNT=${PING_COUNT:-5}
EXPECTED_VERSION=${EXPECTED_VERSION:-}
RECOVERY_ENV_FILE=${RECOVERY_ENV_FILE:-/etc/default/rtw88-mesh-test}
PROVENANCE_TEST=${PROVENANCE_TEST:-/usr/local/libexec/rtw88-qualification/pi_module_provenance.sh}
PREFLIGHT_ONLY=${PREFLIGHT_ONLY:-0}
start_epoch=$(date +%s)

[ "$(id -u)" -eq 0 ] || { echo "run mesh recovery as root" >&2; exit 2; }
[ -n "$EXPECTED_VERSION" ] || {
	if [ -r "$RECOVERY_ENV_FILE" ]; then
		EXPECTED_VERSION=$(sed -n 's/^EXPECTED_VERSION=//p' \
			"$RECOVERY_ENV_FILE")
	fi
}
[ -n "$EXPECTED_VERSION" ] || {
	echo "set EXPECTED_VERSION or provide it in $RECOVERY_ENV_FILE" >&2
	exit 2
}
case $EXPECTED_VERSION in
	*'
'*) echo "EXPECTED_VERSION must have exactly one value" >&2; exit 2 ;;
esac
case $PREFLIGHT_ONLY in
	0|1) ;;
	*) echo "PREFLIGHT_ONLY must be 0 or 1" >&2; exit 2 ;;
esac
for value in "$DEVICE_POLLS" "$ESTAB_POLLS" "$LOCK_WAIT" "$PING_COUNT"; do
	case $value in *[!0-9]*|''|0) echo "poll, wait, and ping counts must be positive integers" >&2; exit 2 ;; esac
done
[ "$ROOT_MAC" != "$PEER_MAC" ] || { echo "ROOT_MAC and PEER_MAC must differ" >&2; exit 2; }
[ -x "$IW" ] || { echo "iw is required at $IW" >&2; exit 2; }
[ -x "$PROVENANCE_TEST" ] || {
	echo "module provenance gate is required at $PROVENANCE_TEST" >&2
	exit 2
}
command -v flock >/dev/null 2>&1 || { echo "flock is required" >&2; exit 2; }

exec 9>"$LOCK_FILE"
if ! flock -w "$LOCK_WAIT" 9; then
	echo "timed out waiting ${LOCK_WAIT}s for $LOCK_FILE" >&2
	exit 75
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

peer_ns_exists()
{
	ip netns list | awk '{ print $1 }' | grep -qx "$PEER_NS"
}

phy_supports_mesh()
{
	"$@" | awk '
		/Supported interface modes:/ { modes = 1; next }
		modes && /^\tBand [0-9]+:/ { exit }
		modes && /\* mesh point/ { found = 1 }
		END { exit !found }
	'
}

poll=0
while :; do
	root_if=$(find_root_if "$ROOT_MAC")
	if peer_ns_exists; then
		peer_if=$(find_peer_if "$PEER_MAC")
	else
		peer_if=
	fi
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

root_driver=$(basename "$(readlink "/sys/class/net/$root_if/device/driver")")
if [ "$root_driver" != "$ROOT_DRIVER" ]; then
	echo "root driver is $root_driver, expected $ROOT_DRIVER" >&2
	exit 1
fi
if [ -n "$peer_if" ]; then
	peer_driver=$(ip netns exec "$PEER_NS" basename \
		"$(ip netns exec "$PEER_NS" readlink "/sys/class/net/$peer_if/device/driver")")
else
	peer_driver=$(basename "$(readlink "/sys/class/net/$peer_root_if/device/driver")")
fi
if [ -n "$PEER_DRIVER" ] && [ "$peer_driver" != "$PEER_DRIVER" ]; then
	echo "peer driver is $peer_driver, expected $PEER_DRIVER" >&2
	exit 78
fi

EXPECTED_VERSION="$EXPECTED_VERSION" "$PROVENANCE_TEST"
if [ "$PREFLIGHT_ONLY" -eq 1 ]; then
	printf 'result=preflight-pass version=%s root_if=%s peer_driver=%s action=none\n' \
		"$EXPECTED_VERSION" "$root_if" "$peer_driver"
	exit 0
fi

root_phy=$($IW dev "$root_if" info | awk '/wiphy/ { print "phy" $2; exit }')
[ -n "$root_phy" ] || { echo "cannot resolve root wiphy" >&2; exit 1; }
if ! phy_supports_mesh $IW phy "$root_phy" info; then
	echo "root wiphy $root_phy does not advertise mesh-point mode" >&2
	exit 78
fi

if [ -n "$peer_if" ]; then
	peer_phy=$(ip netns exec "$PEER_NS" $IW dev "$peer_if" info |
		awk '/wiphy/ { print "phy" $2; exit }')
	peer_iw="ip netns exec $PEER_NS $IW"
else
	peer_phy=$($IW dev "$peer_root_if" info |
		awk '/wiphy/ { print "phy" $2; exit }')
	peer_iw=$IW
fi
[ -n "$peer_phy" ] || { echo "cannot resolve peer wiphy" >&2; exit 1; }
# shellcheck disable=SC2086 # peer_iw intentionally contains the netns prefix.
if ! phy_supports_mesh $peer_iw phy "$peer_phy" info; then
	echo "peer wiphy $peer_phy driver $peer_driver does not advertise mesh-point mode" >&2
	exit 78
fi

if [ -z "$peer_if" ]; then
	peer_ns_exists || ip netns add "$PEER_NS"
	ip link set "$peer_root_if" down
	$IW phy "$peer_phy" set netns name "$PEER_NS"
	peer_if=$(find_peer_if "$PEER_MAC")
	[ -n "$peer_if" ] || { echo "peer netdev missing after namespace move" >&2; exit 1; }
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

ROOT_IP=${ROOT_ADDR%/*}
PEER_IP=${PEER_ADDR%/*}
ping -I "$root_if" -c "$PING_COUNT" -W 1 "$PEER_IP" >/dev/null
ip netns exec "$PEER_NS" ping -I "$peer_if" -c "$PING_COUNT" -W 1 \
	"$ROOT_IP" >/dev/null
root_paths=$($IW dev "$root_if" mpath dump |
	awk 'NR > 1 { count++ } END { print count + 0 }')
peer_paths=$(ip netns exec "$PEER_NS" $IW dev "$peer_if" mpath dump |
	awk 'NR > 1 { count++ } END { print count + 0 }')
if [ "$root_paths" -eq 0 ] || [ "$peer_paths" -eq 0 ]; then
	echo "mesh recovery has no HWMP path root=$root_paths peer=$peer_paths" >&2
	exit 1
fi

printf 'mesh recovered root=%s peer=%s namespace=%s root_driver=%s peer_driver=%s root_paths=%s peer_paths=%s elapsed_s=%s\n' \
	"$root_if" "$peer_if" "$PEER_NS" "$root_driver" "$peer_driver" \
	"$root_paths" "$peer_paths" "$(( $(date +%s) - start_epoch ))"
