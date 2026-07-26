#!/bin/sh
# Validate SAE/AMPE-protected 802.11s between RTL8812AU and a namespace peer.

set -eu

IW=${IW:-/usr/sbin/iw}
WPA=${WPA:-/usr/sbin/wpa_supplicant}
WPA_CLI=${WPA_CLI:-/usr/sbin/wpa_cli}
CONFIG=${CONFIG:-/home/msh/wpa_sae_mesh.conf}
ROOT_IF=${ROOT_IF:-wlan2}
PEER_IF=${PEER_IF:-wlan1}
PEER_NS=${PEER_NS:-meshpeer}
ROOT_MAC=${ROOT_MAC:-fc:22:1c:30:08:c1}
PEER_MAC=${PEER_MAC:-1c:bf:ce:f3:78:4d}
ROOT_IP=${ROOT_IP:-10.45.0.1}
PEER_IP=${PEER_IP:-10.45.0.2}
LOCK_FILE=${LOCK_FILE:-/run/lock/rtw88-mesh-test.lock}
ROOT_LOG=${ROOT_LOG:-/tmp/rtw88-wpa-root.log}
PEER_LOG=${PEER_LOG:-/tmp/rtw88-wpa-peer.log}
OPEN_RECOVERY_HELPER=${OPEN_RECOVERY_HELPER:-/usr/local/libexec/rtw88-mesh-recover}
PEER_DRIVER=${PEER_DRIVER:-rtl8xxxu}
PEER_DRIVER_ID=${PEER_DRIVER_ID:-1-1.4:1.0}

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

root_pid=
peer_pid=
cleanup()
{
	trap - EXIT INT TERM
	set +e
	[ -z "$root_pid" ] || kill "$root_pid" 2>/dev/null || true
	[ -z "$peer_pid" ] || kill "$peer_pid" 2>/dev/null || true
	[ -z "$root_pid" ] || wait "$root_pid" 2>/dev/null || true
	[ -z "$peer_pid" ] || wait "$peer_pid" 2>/dev/null || true
	$IW dev "$ROOT_IF" mesh leave 2>/dev/null || true
	ns $IW dev "$PEER_IF" mesh leave 2>/dev/null || true

	# Let the recovery helper acquire the common test lock. A failed secured
	# beacon update can leave the experimental RTL8192FU unable to beacon even
	# after mesh leave/join; reset only that peer driver if ordinary recovery
	# cannot restore the open test topology.
	command -v flock >/dev/null 2>&1 && flock -u 9
	if [ -x "$OPEN_RECOVERY_HELPER" ] && "$OPEN_RECOVERY_HELPER"; then
		return
	fi
	unbind=/sys/bus/usb/drivers/$PEER_DRIVER/unbind
	bind=/sys/bus/usb/drivers/$PEER_DRIVER/bind
	if [ -w "$unbind" ] && [ -w "$bind" ]; then
		printf '%s' "$PEER_DRIVER_ID" >"$unbind"
		sleep 2
		printf '%s' "$PEER_DRIVER_ID" >"$bind"
		[ ! -x "$OPEN_RECOVERY_HELPER" ] || "$OPEN_RECOVERY_HELPER" || true
	fi
}
trap cleanup EXIT
trap 'exit 130' INT TERM

if [ ! -x "$WPA" ] || [ ! -x "$WPA_CLI" ] || [ ! -r "$CONFIG" ]; then
	echo "missing wpa_supplicant, wpa_cli, or $CONFIG" >&2
	exit 2
fi

current_root=$(ip -o link | awk -v mac="$ROOT_MAC" \
	'tolower($0) ~ tolower(mac) { sub(":", "", $2); print $2; exit }')
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

current_peer=$(ns ip -o link | awk -v mac="$PEER_MAC" \
	'tolower($0) ~ tolower(mac) { sub(":", "", $2); print $2; exit }')
if [ -z "$current_peer" ]; then
	echo "mesh peer interface with MAC $PEER_MAC not found in $PEER_NS" >&2
	exit 1
fi

ns $IW dev "$current_peer" mesh leave 2>/dev/null || true
ns ip link set "$current_peer" down
if [ "$current_peer" != "$PEER_IF" ]; then
	ns ip link set "$current_peer" name "$PEER_IF"
fi
ns $IW dev "$PEER_IF" set type mesh

: >"$ROOT_LOG"
: >"$PEER_LOG"
(exec 9>&-; $WPA -Dnl80211 -i "$ROOT_IF" -c "$CONFIG" -dd) \
	>"$ROOT_LOG" 2>&1 &
root_pid=$!
(exec 9>&-; ns $WPA -Dnl80211 -i "$PEER_IF" -c "$CONFIG" -dd) \
	>"$PEER_LOG" 2>&1 &
peer_pid=$!

poll=0
while [ "$poll" -lt 300 ]; do
	if $IW dev "$ROOT_IF" station dump 2>/dev/null |
		grep -q 'mesh plink:[[:space:]]*ESTAB' &&
		ns $IW dev "$PEER_IF" station dump 2>/dev/null |
		grep -q 'mesh plink:[[:space:]]*ESTAB'; then
		break
	fi
	if ! kill -0 "$root_pid" 2>/dev/null || ! kill -0 "$peer_pid" 2>/dev/null; then
		echo "a supplicant exited before peering" >&2
		exit 1
	fi
	poll=$((poll + 1))
	sleep 0.1
done

if [ "$poll" -ge 300 ]; then
	echo "secured peer did not establish within 30 seconds" >&2
	exit 1
fi

ip addr flush dev "$ROOT_IF"
ip addr add "$ROOT_IP/24" dev "$ROOT_IF"
ns ip addr flush dev "$PEER_IF"
ns ip addr add "$PEER_IP/24" dev "$PEER_IF"

echo ROOT_STATUS
$WPA_CLI -i "$ROOT_IF" status
echo PEER_STATUS
ns $WPA_CLI -i "$PEER_IF" status
echo ROOT_STATION
$IW dev "$ROOT_IF" station dump
echo PEER_STATION
ns $IW dev "$PEER_IF" station dump
echo ROOT_TO_PEER
ping -I "$ROOT_IF" -c 20 -W 1 "$PEER_IP"
echo PEER_TO_ROOT
ns ping -I "$PEER_IF" -c 20 -W 1 "$ROOT_IP"
echo LOGS "$ROOT_LOG" "$PEER_LOG"
