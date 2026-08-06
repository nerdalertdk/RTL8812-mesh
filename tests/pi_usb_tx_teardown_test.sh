#!/bin/sh
# Prove that RTL88 USB teardown synchronously kills an in-flight TX anchor.

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
FLOODERS=${FLOODERS:-8}
REBIND_POLLS=${REBIND_POLLS:-100}
LOG_DIR=${LOG_DIR:-/var/tmp/rtl8812au-mesh/usb-tx-teardown}
submit_param=/sys/module/rtw_usb/parameters/test_tx_submit_failures
completion_param=/sys/module/rtw_usb/parameters/test_tx_completion_failures

[ "$(id -u)" -eq 0 ] || { echo "run this hardware test as root" >&2; exit 2; }
for value in "$FLOODERS" "$REBIND_POLLS"; do
	case $value in *[!0-9]*|''|0) echo "counts must be positive integers" >&2; exit 2 ;; esac
done
[ -x "$IW" ] || { echo "iw is required at $IW" >&2; exit 2; }
command -v flock >/dev/null 2>&1 || { echo "flock is required" >&2; exit 2; }
command -v journalctl >/dev/null 2>&1 || { echo "journalctl is required" >&2; exit 2; }
[ -w "$submit_param" ] && [ -w "$completion_param" ] || {
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

flood_pids=
bound=1
driver_id=
bind_path=

stop_flood()
{
	for pid in $flood_pids; do
		kill "$pid" 2>/dev/null || true
	done
	for pid in $flood_pids; do
		wait "$pid" 2>/dev/null || true
	done
	flood_pids=
}

cleanup()
{
	stop_flood
	if [ "$bound" -eq 0 ] && [ -n "$driver_id" ] && [ -w "$bind_path" ]; then
		printf '%s' "$driver_id" >"$bind_path" 2>/dev/null || true
	fi
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

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

$IW dev "$ROOT_IF" station dump | grep -q 'mesh plink:[[:space:]]*ESTAB'
ns $IW dev "$PEER_IF" station dump | grep -q 'mesh plink:[[:space:]]*ESTAB'
ping -I "$ROOT_IF" -c 10 -W 1 "$PEER_IP" >/dev/null
ns ping -I "$PEER_IF" -c 10 -W 1 "$ROOT_IP" >/dev/null

driver_id=$(basename "$(readlink -f "/sys/class/net/$ROOT_IF/device")")
unbind_path=/sys/bus/usb/drivers/$ROOT_DRIVER/unbind
bind_path=/sys/bus/usb/drivers/$ROOT_DRIVER/bind
[ -w "$unbind_path" ] && [ -w "$bind_path" ] || {
	echo "USB bind controls are unavailable for $ROOT_DRIVER" >&2
	exit 2
}

mkdir -p "$LOG_DIR"
run_id=$(date -u +%Y%m%dT%H%M%SZ)
log=$LOG_DIR/tx-teardown-$run_id.log
kernel_log=$LOG_DIR/tx-teardown-$run_id-kernel.log
echo "result_log=$log kernel_log=$kernel_log"
exec >"$log" 2>&1
start_epoch=$(date +%s)

i=0
while [ "$i" -lt "$FLOODERS" ]; do
	ping -I "$ROOT_IF" -s 1400 -i 0.001 "$PEER_IP" >/dev/null 2>&1 &
	flood_pids="$flood_pids $!"
	i=$((i + 1))
done
sleep 1

bound=0
printf '%s' "$driver_id" >"$unbind_path"
stop_flood
printf '%s' "$driver_id" >"$bind_path"
bound=1

poll=0
while [ "$poll" -lt "$REBIND_POLLS" ]; do
	ROOT_IF=$(find_root_if)
	if [ -n "$ROOT_IF" ] &&
	   [ "$(basename "$(readlink "/sys/class/net/$ROOT_IF/device/driver" 2>/dev/null || true)")" = "$ROOT_DRIVER" ]; then
		break
	fi
	poll=$((poll + 1))
	sleep 0.1
done
[ -n "$ROOT_IF" ] && [ "$poll" -lt "$REBIND_POLLS" ] || {
	echo "RTL8812AU did not rebind" >&2
	exit 1
}
$IW dev "$ROOT_IF" info >/dev/null

journalctl -k --since "@$start_epoch" --no-pager >"$kernel_log" 2>&1
pending=$(grep -c 'test: USB TX anchor pending before kill=1' "$kernel_log" || true)
faults=$(grep -Ei 'BUG:|WARNING:|Oops:|KASAN|UBSAN|use-after-free|general protection fault|kernel NULL pointer|refcount_t:|error -71|EPROTO|over.?current|under.?voltage|usb .*disconnect|usb .*reset|recoverable RX URB|transient RX URB submit error|USB TX URB error|read register .* (recovered|failed)|write register .* failed' \
	"$kernel_log" || true)
fault_count=$(printf '%s\n' "$faults" | sed '/^$/d' | awk 'END { print NR + 0 }')
printf 'result=complete driver_id=%s pending_anchor_events=%s fault_events=%s rebind_polls=%s root_if=%s\n' \
	"$driver_id" "$pending" "$fault_count" "$poll" "$ROOT_IF"
printf '%s\n' "$faults" | sed '/^$/d'

# Rebinding proves the interface driver remains usable. The mesh interface is
# intentionally reconstructed only after the disposable module is replaced by
# the exact production build.
[ "$pending" -gt 0 ] && [ "$fault_count" -eq 0 ]
