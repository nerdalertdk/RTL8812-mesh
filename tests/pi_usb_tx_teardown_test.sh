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
RECOVERY_UNIT=${RECOVERY_UNIT:-rtw88-mesh-recover.service}
FLOODERS=${FLOODERS:-8}
REBIND_POLLS=${REBIND_POLLS:-100}
DELAY_POLLS=${DELAY_POLLS:-200}
UNBIND_TIMEOUT_SECONDS=${UNBIND_TIMEOUT_SECONDS:-20}
LOG_DIR=${LOG_DIR:-/var/tmp/rtl8812au-mesh/usb-tx-teardown}
submit_param=/sys/module/rtw_usb/parameters/test_tx_submit_failures
completion_param=/sys/module/rtw_usb/parameters/test_tx_completion_failures
delay_param=/sys/module/rtw_usb/parameters/test_tx_completion_delays
delay_device_param=/sys/module/rtw_usb/parameters/test_tx_completion_delay_device

[ "$(id -u)" -eq 0 ] || { echo "run this hardware test as root" >&2; exit 2; }
for value in "$FLOODERS" "$REBIND_POLLS" "$DELAY_POLLS" \
	"$UNBIND_TIMEOUT_SECONDS"; do
	case $value in *[!0-9]*|''|0) echo "counts must be positive integers" >&2; exit 2 ;; esac
done
[ -x "$IW" ] || { echo "iw is required at $IW" >&2; exit 2; }
command -v flock >/dev/null 2>&1 || { echo "flock is required" >&2; exit 2; }
command -v journalctl >/dev/null 2>&1 || { echo "journalctl is required" >&2; exit 2; }
command -v systemctl >/dev/null 2>&1 || { echo "systemctl is required" >&2; exit 2; }
command -v timeout >/dev/null 2>&1 || { echo "timeout is required" >&2; exit 2; }
[ -w "$submit_param" ] && [ -w "$completion_param" ] &&
   [ -w "$delay_param" ] && [ -w "$delay_device_param" ] || {
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
	printf '0\n' >"$delay_param" 2>/dev/null || true
	printf 'none\n' >"$delay_device_param" 2>/dev/null || true
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
printf '0\n' >"$submit_param"
printf '0\n' >"$completion_param"
printf '%s\n' "$driver_id" >"$delay_device_param"
printf '1\n' >"$delay_param"

i=0
while [ "$i" -lt "$FLOODERS" ]; do
	ping -I "$ROOT_IF" -s 1400 -i 0.001 "$PEER_IP" >/dev/null 2>&1 &
	flood_pids="$flood_pids $!"
	i=$((i + 1))
done

poll=0
while [ "$(cat "$delay_param")" -gt 0 ] && [ "$poll" -lt "$DELAY_POLLS" ]; do
	poll=$((poll + 1))
	sleep 0.01
done
[ "$(cat "$delay_param")" -eq 0 ] || {
	echo "no TX completion entered the deterministic delay" >&2
	exit 1
}

bound=0
unbind_start=$(date +%s)
if ! timeout --foreground -k 5 "$UNBIND_TIMEOUT_SECONDS" \
	sh -c 'printf "%s" "$1" >"$2"' sh "$driver_id" "$unbind_path"; then
	echo "RTL8812AU unbind exceeded ${UNBIND_TIMEOUT_SECONDS}s or failed" >&2
	exit 1
fi
unbind_elapsed=$(( $(date +%s) - unbind_start ))
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
# Rebind queues udev recovery. Stop it before releasing the shared lock so it
# cannot reconstruct a mesh with the disposable module.
systemctl stop "$RECOVERY_UNIT"

journalctl -k --since "@$start_epoch" --no-pager >"$kernel_log" 2>&1
inflight=$(grep 'test: USB TX anchor before kill ' "$kernel_log" |
	awk '/pending_urbs=[1-9][0-9]*|active_callbacks=[1-9][0-9]*/ { count++ }
	     END { print count + 0 }')
quiesced=$(grep -c 'test: USB TX anchor after kill pending_urbs=0 active_callbacks=0' \
	"$kernel_log" || true)
faults=$(grep -Ei 'BUG:|WARNING:|Oops:|KASAN|UBSAN|use-after-free|general protection fault|kernel NULL pointer|refcount_t:|error -71|EPROTO|over.?current|under.?voltage|usb .*disconnect|usb .*reset|recoverable RX URB|transient RX URB submit error|USB TX URB error|read register .* (recovered|failed)|write register .* failed' \
	"$kernel_log" || true)
fault_count=$(printf '%s\n' "$faults" | sed '/^$/d' | awk 'END { print NR + 0 }')
printf 'result=complete driver_id=%s unbind_elapsed_s=%s pre_kill_inflight=%s post_kill_quiesced=%s fault_events=%s rebind_polls=%s root_if=%s\n' \
	"$driver_id" "$unbind_elapsed" "$inflight" "$quiesced" \
	"$fault_count" "$poll" "$ROOT_IF"
printf '%s\n' "$faults" | sed '/^$/d'

# Rebinding proves the interface driver remains usable. The stopped recovery
# unit must be started explicitly after the exact production build is restored.
[ "$inflight" -gt 0 ] && [ "$quiesced" -gt 0 ] && [ "$fault_count" -eq 0 ]
