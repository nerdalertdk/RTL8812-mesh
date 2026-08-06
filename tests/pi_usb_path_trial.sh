#!/bin/sh
# Execute and preserve one controlled row/repetition of USB_PATH_MATRIX.md.

set -eu
umask 077

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
case $DURATION_SECONDS in *[!0-9]*|''|0) echo "DURATION_SECONDS must be positive" >&2; exit 2 ;; esac
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
mkdir -p "$LOG_ROOT/row-$ROW"
if ! mkdir "$trial"; then
	echo "trial directory already exists: $trial" >&2
	exit 2
fi
available_kib=$(df -Pk "$trial" | awk 'NR == 2 { print $4 }')
required_kib=$((FILE_MIB * 1024 * 3 + 204800))
if [ -z "$available_kib" ] || [ "$available_kib" -lt "$required_kib" ]; then
	echo "insufficient space: available_kib=${available_kib:-unknown} required_kib=$required_kib" >&2
	exit 2
fi
start_epoch=$(date +%s)
context_epoch=$((start_epoch - 30))
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
	B) case $usb_device in
		1-1.*.*) echo "row B has an extra downstream hub: $usb_device" >&2; exit 1 ;;
		1-1.*) ;;
		*) echo "row B is not a direct Pi USB2 path: $usb_device" >&2; exit 1 ;;
	   esac ;;
	C) case $usb_device in 2-*.*) ;; *) echo "row C has no downstream USB3 hub: $usb_device" >&2; exit 1 ;; esac ;;
	D) case $usb_device in 1-1.*.*) ;; *) echo "row D has no downstream USB2 hub: $usb_device" >&2; exit 1 ;; esac ;;
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
		for module in rtw_core rtw_usb rtw_88xxa rtw_8812a rtw_8812au; do
			installed=$(/sbin/modinfo -F srcversion "$module" 2>/dev/null || true)
			loaded=$(cat "/sys/module/$module/srcversion" 2>/dev/null || true)
			path=$(/sbin/modinfo -n "$module" 2>/dev/null || true)
			match=no
			if [ -n "$installed" ] && [ "$installed" = "$loaded" ]; then
				match=yes
			fi
			printf 'module=%s path=%s installed_srcversion=%s loaded_srcversion=%s match=%s\n' \
				"$module" "${path:-unavailable}" "${installed:-unavailable}" \
				"${loaded:-unavailable}" "$match"
		done
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
	echo "root_if=$root_if"
	echo "root_driver=$root_driver"
	echo "usb_device=$usb_device"
	echo "usb_speed_mbps=$usb_speed"
	echo "expected_speed_mbps=$expected_speed"
	echo "duration_seconds=$DURATION_SECONDS"
	echo "file_mib=$FILE_MIB"
} >"$metadata"

capture_state pre
pre_throttle=$(throttle_value)
pre_provenance_mismatches=$(grep -c 'match=no' "$trial/pre-state.log" || true)
if [ "$pre_provenance_mismatches" -ne 0 ]; then
	{
		echo "result=invalid"
		echo "classification=invalid-module-provenance"
		echo "pre_provenance_mismatches=$pre_provenance_mismatches"
		echo "trial_dir=$trial"
	} | tee "$trial/result.log"
	exit 2
fi

# A pre-existing soft-temperature history bit makes a recurrence during this
# trial unobservable once the current condition clears. Require a reboot and
# adequate cooling before starting attribution work. Other historical upper
# bits remain evidence but do not by themselves invalidate a new interval.
pre_environment_fault=0
case $pre_throttle in
	0x*)
		pre_throttle_num=$((pre_throttle))
		[ $((pre_throttle_num & 0xf)) -eq 0 ] || pre_environment_fault=1
		[ $((pre_throttle_num & 0x80000)) -eq 0 ] || pre_environment_fault=1
		;;
	*) pre_environment_fault=1 ;;
esac
if [ "$pre_environment_fault" -ne 0 ]; then
	{
		echo "result=invalid"
		echo "classification=invalid-pre-run-environment-state"
		echo "pre_throttled=${pre_throttle:-unavailable}"
		echo "trial_dir=$trial"
	} | tee "$trial/result.log"
	exit 2
fi

soak_status=0
LOCK_FD_INHERITED=9 LOG_DIR="$trial/soak" \
	DURATION_SECONDS="$DURATION_SECONDS" ROOT_MAC="$ROOT_MAC" \
	PEER_MAC="$PEER_MAC" PEER_NS="$PEER_NS" "$SOAK_TEST" || soak_status=$?

soak_summary=$(readlink -f "$trial/soak/latest-summary.log" 2>/dev/null || true)
soak_workload_failed=0
case $soak_status in
	0|4) ;;
	*) soak_workload_failed=1 ;;
esac
if [ "$soak_workload_failed" -eq 0 ]; then
	if [ -z "$soak_summary" ] || [ ! -r "$soak_summary" ]; then
		soak_workload_failed=1
	else
		completed=$(sed -n 's/^completed=//p' "$soak_summary")
		state_total=$(sed -n 's/^state_total=//p' "$soak_summary")
		state_established=$(sed -n 's/^state_established=//p' "$soak_summary")
		state_unavailable=$(sed -n 's/^state_unavailable=//p' "$soak_summary")
		ping_failed=$(sed -n 's/^ping_batches_failed=//p' "$soak_summary")
		transfers_failed=$(sed -n 's/^transfers_failed=//p' "$soak_summary")
		invalidations=$(sed -n 's/^invalidations=//p' "$soak_summary")
		case $completed:$state_total:$state_established:$state_unavailable:$ping_failed:$transfers_failed:$invalidations in
			:*|*::*|*:|*[!0-9:]*) soak_workload_failed=1 ;;
			*)
				if [ "$completed" -ne 1 ] || [ "$state_total" -eq 0 ] ||
				   [ "$state_total" -ne "$state_established" ] ||
				   [ "$state_unavailable" -ne 0 ] ||
				   [ "$ping_failed" -ne 0 ] ||
				   [ "$transfers_failed" -ne 0 ] ||
				   [ "$invalidations" -ne 0 ]; then
					soak_workload_failed=1
				fi
				;;
		esac
	fi
fi

transfer_status=0
transfer_ran=0
if [ "$soak_workload_failed" -eq 0 ]; then
	transfer_ran=1
	LOCK_FD_INHERITED=9 LOG_DIR="$trial/transfer" FILE_MIB="$FILE_MIB" \
		ROOT_MAC="$ROOT_MAC" PEER_MAC="$PEER_MAC" PEER_NS="$PEER_NS" \
		"$TRANSFER_TEST" || transfer_status=$?
fi

capture_state post
post_throttle=$(throttle_value)
post_topology_mismatch=0
post_root_if=$(find_root_if)
if [ -z "$post_root_if" ]; then
	post_topology_mismatch=1
else
	post_driver=$(basename "$(readlink "/sys/class/net/$post_root_if/device/driver")")
	post_usb_interface=$(basename "$(readlink -f "/sys/class/net/$post_root_if/device")")
	post_usb_device=${post_usb_interface%%:*}
	post_usb_speed=$(cat "/sys/bus/usb/devices/$post_usb_device/speed" 2>/dev/null || true)
	if [ "$post_driver" != "$ROOT_DRIVER" ] ||
	   [ "$post_usb_device" != "$usb_device" ] ||
	   [ "$post_usb_speed" != "$usb_speed" ]; then
		post_topology_mismatch=1
	fi
fi
journalctl -k --since "@$start_epoch" --no-pager >"$trial/kernel.log" 2>&1 || true
journalctl -k --since "@$context_epoch" --no-pager \
	>"$trial/kernel-context.log" 2>&1 || true
transport_events=$(grep -Eic 'error -71|EPROTO|usb .*disconnect|usb .*reset|recoverable RX URB|transient RX URB submit error|USB TX URB error|read register .* (recovered|failed)|write register .* failed' \
	"$trial/kernel.log" 2>/dev/null || true)
post_provenance_mismatches=$(grep -c 'match=no' "$trial/post-state.log" || true)

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
soak_environment_invalidations=$(grep -Eic 'event=invalid reason=thermal-limit' \
	"$trial"/soak/soak-*.log 2>/dev/null || true)
[ -n "$soak_environment_invalidations" ] || soak_environment_invalidations=0

classification=valid
result=pass
if [ "$current_power_fault" -ne 0 ]; then
	classification=invalid-current-power-state
	result=invalid
elif [ "$new_historical_power_fault" -ne 0 ] ||
     [ "$kernel_power_events" -ne 0 ] ||
     [ "$soak_environment_invalidations" -ne 0 ]; then
	classification=invalid-environment-event-during-trial
	result=invalid
elif [ "$post_provenance_mismatches" -ne 0 ]; then
	classification=invalid-module-provenance
	result=invalid
elif [ "$transport_events" -ne 0 ]; then
	if [ "$soak_workload_failed" -ne 0 ] || [ "$transfer_status" -ne 0 ] ||
	   [ "$post_topology_mismatch" -ne 0 ]; then
		classification=transport-event-with-workload-or-topology-failure
	else
		classification=recovered-transport-event-review-required
	fi
	result=event
elif [ "$post_topology_mismatch" -ne 0 ]; then
	classification=topology-changed-without-classified-kernel-event
	result=fail
elif [ "$soak_workload_failed" -ne 0 ] || [ "$transfer_status" -ne 0 ]; then
	classification=workload-failure
	result=fail
fi

{
	echo "result=$result"
	echo "classification=$classification"
	echo "soak_status=$soak_status"
	echo "soak_workload_failed=$soak_workload_failed"
	echo "transfer_ran=$transfer_ran"
	echo "transfer_status=$transfer_status"
	echo "pre_throttled=${pre_throttle:-unavailable}"
	echo "post_throttled=${post_throttle:-unavailable}"
	echo "kernel_power_events=$kernel_power_events"
	echo "soak_environment_invalidations=$soak_environment_invalidations"
	echo "transport_events=$transport_events"
	echo "pre_provenance_mismatches=$pre_provenance_mismatches"
	echo "post_provenance_mismatches=$post_provenance_mismatches"
	echo "post_root_if=${post_root_if:-unavailable}"
	echo "post_topology_mismatch=$post_topology_mismatch"
	echo "trial_dir=$trial"
} | tee "$trial/result.log"

case $result in pass) exit 0 ;; invalid) exit 2 ;; event) exit 4 ;; *) exit 1 ;; esac
