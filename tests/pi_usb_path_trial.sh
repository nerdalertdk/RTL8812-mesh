#!/bin/sh
# Execute and preserve one controlled row/repetition of USB_PATH_MATRIX.md.

set -eu

ROW=${ROW:?set ROW to A, B, C, or D}
REPETITION=${REPETITION:?set REPETITION to a positive integer}
ROOT_MAC=${ROOT_MAC:?set ROOT_MAC to the RTL8812AU under test}
PEER_MAC=${PEER_MAC:?set PEER_MAC to the mesh peer}
PSU_DESC=${PSU_DESC:?describe the fixed Pi power supply}
DUT_ID=${DUT_ID:?record the DUT label/VID:PID/serial}
PORT_DESC=${PORT_DESC:?describe the physical Pi/hub port and cable}
HUB_DESC=${HUB_DESC:-none-direct}
PEER_NS=${PEER_NS:-meshpeer}
SOAK_TEST=${SOAK_TEST:?set SOAK_TEST to the absolute pi_mesh_soak.sh path}
TRANSFER_TEST=${TRANSFER_TEST:?set TRANSFER_TEST to the absolute pi_mesh_transfer.sh path}
DURATION_SECONDS=${DURATION_SECONDS:-28800}
FILE_MIB=${FILE_MIB:-512}
LOG_ROOT=${LOG_ROOT:-/var/tmp/rtl8812au-mesh/usb-path-matrix}
LOCK_FILE=${LOCK_FILE:-/run/lock/rtw88-mesh-test.lock}
ROOT_DRIVER=${ROOT_DRIVER:-rtw_8812au}

case $ROW in A|B|C|D) ;; *) echo "ROW must be A, B, C, or D" >&2; exit 2 ;; esac
case $REPETITION in *[!0-9]*|''|0) echo "REPETITION must be positive" >&2; exit 2 ;; esac
case $DURATION_SECONDS in *[!0-9]*|'') echo "DURATION_SECONDS must be an integer" >&2; exit 2 ;; esac
case $FILE_MIB in *[!0-9]*|''|0) echo "FILE_MIB must be positive" >&2; exit 2 ;; esac
case $ROW in A|C) expected_speed=5000 ;; B|D) expected_speed=480 ;; esac
case $ROW in
	A|B) [ "$HUB_DESC" = none-direct ] || {
		echo "rows A/B require HUB_DESC=none-direct" >&2; exit 2;
	} ;;
	C|D) [ "$HUB_DESC" != none-direct ] && [ "$HUB_DESC" != none ] || {
		echo "rows C/D require an independently powered hub description" >&2
		exit 2
	} ;;
esac
for executable in "$SOAK_TEST" "$TRANSFER_TEST"; do
	[ -x "$executable" ] || { echo "not executable: $executable" >&2; exit 2; }
done
[ "$(id -u)" -eq 0 ] || { echo "run this hardware test as root" >&2; exit 2; }
command -v flock >/dev/null 2>&1 || { echo "flock is required" >&2; exit 2; }

exec 9>"$LOCK_FILE"
if ! flock -n 9; then
	echo "another rtw88 mesh test holds $LOCK_FILE" >&2
	exit 75
fi

run_id=$(date -u +%Y%m%dT%H%M%SZ)
trial=$LOG_ROOT/row-$ROW/rep-$REPETITION-$run_id
mkdir -p "$trial"
start_epoch=$(date +%s)
metadata=$trial/metadata.log

find_root_if()
{
	ip -o link 2>/dev/null | awk -v mac="$ROOT_MAC" '
		tolower($0) ~ tolower(mac) { sub(/:$/, "", $2); print $2; exit }
	'
}

root_if=$(find_root_if)
[ -n "$root_if" ] || { echo "RTL8812AU interface not found" >&2; exit 1; }
root_driver=$(basename "$(readlink "/sys/class/net/$root_if/device/driver")")
[ "$root_driver" = "$ROOT_DRIVER" ] || {
	echo "root driver is $root_driver, expected $ROOT_DRIVER" >&2; exit 1;
}
usb_interface=$(basename "$(readlink -f "/sys/class/net/$root_if/device")")
usb_device=${usb_interface%%:*}
usb_sysfs=/sys/bus/usb/devices/$usb_device
[ -r "$usb_sysfs/speed" ] || { echo "USB speed unavailable for $usb_device" >&2; exit 1; }
usb_speed=$(cat "$usb_sysfs/speed")
[ "$usb_speed" = "$expected_speed" ] || {
	echo "row $ROW requires ${expected_speed}M, negotiated ${usb_speed}M" >&2
	exit 1
}

# Raspberry Pi 4 USB2 ports sit behind its internal 1-1 hub. These checks
# reject an extra hub in direct rows and require one in the USB3 powered row.
case $ROW in
	A) case $usb_device in 2-*.*) echo "row A is not a direct USB3 path: $usb_device" >&2; exit 1 ;; esac ;;
	B) case $usb_device in 1-1.*.*) echo "row B has an extra downstream hub: $usb_device" >&2; exit 1 ;; esac ;;
	C) case $usb_device in 2-*.*) ;; *) echo "row C has no downstream USB3 hub: $usb_device" >&2; exit 1 ;; esac ;;
esac

throttle_value()
{
	vcgencmd get_throttled 2>/dev/null | sed -n 's/^throttled=//p'
}

capture_state()
{
	phase=$1
	{
		echo "phase=$phase"
		date --iso-8601=seconds
		uname -a
		cat /proc/sys/kernel/random/boot_id
		/sbin/dkms status rtl8812au-mesh 2>&1 || true
		/sbin/modinfo -n rtw_usb 2>&1 || true
		/sbin/modinfo -F srcversion rtw_usb 2>&1 || true
		cat /sys/module/rtw_usb/srcversion 2>&1 || true
		lsusb 2>&1 || true
		lsusb -t 2>&1 || true
		vcgencmd get_throttled 2>&1 || true
		vcgencmd measure_temp 2>&1 || true
	} >"$trial/$phase-state.log"
}

{
	echo "run_id=$run_id"
	echo "row=$ROW"
	echo "repetition=$REPETITION"
	echo "dut_id=$DUT_ID"
	echo "root_mac=$ROOT_MAC"
	echo "peer_mac=$PEER_MAC"
	echo "psu_desc=$PSU_DESC"
	echo "hub_desc=$HUB_DESC"
	echo "port_desc=$PORT_DESC"
	echo "duration_seconds=$DURATION_SECONDS"
	echo "file_mib=$FILE_MIB"
} >"$metadata"

capture_state pre
pre_throttle=$(throttle_value)

soak_status=0
LOCK_FD_INHERITED=9 LOG_DIR="$trial/soak" \
	DURATION_SECONDS="$DURATION_SECONDS" ROOT_MAC="$ROOT_MAC" \
	PEER_MAC="$PEER_MAC" PEER_NS="$PEER_NS" "$SOAK_TEST" || soak_status=$?

soak_summary=$(readlink -f "$trial/soak/latest-summary.log" 2>/dev/null || true)
if [ "$soak_status" -eq 0 ]; then
	if [ -z "$soak_summary" ] || [ ! -r "$soak_summary" ]; then
		soak_status=1
	else
		state_total=$(sed -n 's/^state_total=//p' "$soak_summary")
		state_established=$(sed -n 's/^state_established=//p' "$soak_summary")
		state_unavailable=$(sed -n 's/^state_unavailable=//p' "$soak_summary")
		ping_failed=$(sed -n 's/^ping_batches_failed=//p' "$soak_summary")
		transfers_failed=$(sed -n 's/^transfers_failed=//p' "$soak_summary")
		invalidations=$(sed -n 's/^invalidations=//p' "$soak_summary")
		if [ -z "$state_total" ] || [ "$state_total" -eq 0 ] ||
		   [ "$state_total" -ne "$state_established" ] ||
		   [ "${state_unavailable:-1}" -ne 0 ] ||
		   [ "${ping_failed:-1}" -ne 0 ] ||
		   [ "${transfers_failed:-1}" -ne 0 ] ||
		   [ "${invalidations:-1}" -ne 0 ]; then
			soak_status=1
		fi
	fi
fi

transfer_status=0
if [ "$soak_status" -eq 0 ]; then
	LOCK_FD_INHERITED=9 LOG_DIR="$trial/transfer" FILE_MIB="$FILE_MIB" \
		ROOT_MAC="$ROOT_MAC" PEER_MAC="$PEER_MAC" PEER_NS="$PEER_NS" \
		"$TRANSFER_TEST" || transfer_status=$?
fi

capture_state post
post_throttle=$(throttle_value)
journalctl -k --since "@$start_epoch" --no-pager >"$trial/kernel.log" 2>&1 || true

current_power_fault=0
new_historical_power_fault=0
case $pre_throttle:$post_throttle in
	0x*:0x*)
		pre_throttle_num=$((pre_throttle))
		post_throttle_num=$((post_throttle))
		[ $(( (pre_throttle_num | post_throttle_num) & 0xf )) -eq 0 ] ||
			current_power_fault=1
		[ $((post_throttle_num & 0xf0000 & ~pre_throttle_num)) -eq 0 ] ||
			new_historical_power_fault=1
		;;
	*) current_power_fault=1 ;;
esac
kernel_power_events=$(grep -Eic 'under.?voltage|over.?current' \
	"$trial/kernel.log" 2>/dev/null || true)

classification=valid
result=pass
if [ "$current_power_fault" -ne 0 ]; then
	classification=invalid-current-power-state
	result=invalid
elif [ "$new_historical_power_fault" -ne 0 ] ||
     [ "$kernel_power_events" -ne 0 ]; then
	classification=invalid-power-event-during-trial
	result=invalid
elif [ "$soak_status" -ne 0 ] || [ "$transfer_status" -ne 0 ]; then
	result=fail
fi

{
	echo "result=$result"
	echo "classification=$classification"
	echo "soak_status=$soak_status"
	echo "transfer_status=$transfer_status"
	echo "pre_throttled=${pre_throttle:-unavailable}"
	echo "post_throttled=${post_throttle:-unavailable}"
	echo "kernel_power_events=$kernel_power_events"
	echo "trial_dir=$trial"
} | tee "$trial/result.log"

case $result in pass) exit 0 ;; invalid) exit 2 ;; *) exit 1 ;; esac
