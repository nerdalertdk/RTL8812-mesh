#!/bin/sh
# Recovery-aware RTL8812AU/RTL8192FU mesh endurance harness.

set -u

IW=${IW:-/usr/sbin/iw}
ROOT_MAC=${ROOT_MAC:?set ROOT_MAC to the primary adapter MAC}
PEER_MAC=${PEER_MAC:?set PEER_MAC to the peer adapter MAC}
PEER_NS=${PEER_NS:-meshpeer}
ROOT_IP=${ROOT_IP:-10.44.0.1}
PEER_IP=${PEER_IP:-10.44.0.2}
DURATION_SECONDS=${DURATION_SECONDS:-28800}
POLL_SECONDS=${POLL_SECONDS:-30}
TRANSFER_SECONDS=${TRANSFER_SECONDS:-3600}
TRANSFER_MIB=${TRANSFER_MIB:-10}
LOG_DIR=${LOG_DIR:-/var/tmp/rtl8812au-mesh/mesh-soak}
LOCK_FILE=${LOCK_FILE:-/run/lock/rtw88-mesh-test.lock}
LOCK_WAIT=${LOCK_WAIT:-90}
THERMAL_ZONE=${THERMAL_ZONE:-/sys/class/thermal/thermal_zone0/temp}
MAX_TEMP_MILLIC=${MAX_TEMP_MILLIC:-85000}

run_id=$(date -u +%Y%m%dT%H%M%SZ)
log=$LOG_DIR/soak-$run_id.log
summary=$LOG_DIR/summary-$run_id.log
http_log=$LOG_DIR/http-$run_id.log
root_source=/tmp/rtw88-soak-root-$run_id.bin
peer_source=/tmp/rtw88-soak-peer-$run_id.bin
root_received=/tmp/rtw88-soak-root-received-$run_id.bin
peer_received=/tmp/rtw88-soak-peer-received-$run_id.bin
root_http_pid=
peer_http_pid=
start_epoch=$(date +%s)
end_epoch=$((start_epoch + DURATION_SECONDS))
next_transfer=$start_epoch
kernel_since=$(date '+%Y-%m-%d %H:%M:%S')

mkdir -p "$LOG_DIR"
ln -sfn "$log" "$LOG_DIR/latest.log"
# Point at this run immediately.  Until write_summary() creates the target, a
# dangling link is preferable to silently exposing the previous run's summary.
ln -sfn "$summary" "$LOG_DIR/latest-summary.log"

log_event()
{
	printf '%s %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$*" |
		tee -a "$log"
}

find_root_if()
{
	ip -o link 2>/dev/null | awk -v mac="$1" '
		tolower($0) ~ tolower(mac) { sub(/:$/, "", $2); print $2; exit }
	'
}

find_peer_if()
{
	ip netns exec "$PEER_NS" ip -o link 2>/dev/null |
		awk -v mac="$1" '
			tolower($0) ~ tolower(mac) { sub(/:$/, "", $2); print $2; exit }
		'
}

secure_test_running()
{
	for pid_file in /run/wpa-sec-root.pid /run/wpa-sec-peer.pid; do
		if [ -r "$pid_file" ]; then
			pid=$(cat "$pid_file" 2>/dev/null || true)
			[ -n "$pid" ] && kill -0 "$pid" 2>/dev/null && return 0
		fi
	done
	return 1
}

has_ipv4()
{
	mode=$1
	interface=$2
	address=$3
	if [ "$mode" = peer ]; then
		ip netns exec "$PEER_NS" ip -o -4 addr show dev "$interface" \
			2>/dev/null | grep -q " inet $address/"
	else
		ip -o -4 addr show dev "$interface" 2>/dev/null |
			grep -q " inet $address/"
	fi
}

mesh_mfp()
{
	mode=$1
	interface=$2
	if [ "$mode" = peer ]; then
		ip netns exec "$PEER_NS" $IW dev "$interface" station dump \
			2>/dev/null | awk '/MFP:/ { print $2; exit }'
	else
		$IW dev "$interface" station dump 2>/dev/null |
			awk '/MFP:/ { print $2; exit }'
	fi
}

read_temp_millic()
{
	if [ -r "$THERMAL_ZONE" ]; then
		cat "$THERMAL_ZONE" 2>/dev/null || printf 'unavailable\n'
	else
		printf 'unavailable\n'
	fi
}

read_throttled()
{
	vcgencmd get_throttled 2>/dev/null |
		sed -n 's/^throttled=//p' || true
}

open_topology_ready()
{
	root_if=$1
	peer_if=$2
	has_ipv4 root "$root_if" "$ROOT_IP" || return 1
	has_ipv4 peer "$peer_if" "$PEER_IP" || return 1
	[ "$(mesh_mfp root "$root_if")" = no ] || return 1
	[ "$(mesh_mfp peer "$peer_if")" = no ] || return 1
	ping -I "$root_if" -c 3 -W 1 "$PEER_IP" >/dev/null 2>&1 || return 1
	ip netns exec "$PEER_NS" ping -I "$peer_if" -c 3 -W 1 "$ROOT_IP" \
		>/dev/null 2>&1 || return 1
	return 0
}

stop_servers()
{
	for pid in "$root_http_pid" "$peer_http_pid"; do
		[ -n "$pid" ] && kill "$pid" 2>/dev/null || true
	done
	root_http_pid=
	peer_http_pid=
}

yield_for_recovery()
{
	# A USB return triggers the recovery service, which uses the same lock.
	# Yield it a bounded window, then resume exclusive test ownership.
	log_event "event=recovery-window result=yield"
	flock -u 9
	sleep 5
	if ! flock -w "$LOCK_WAIT" 9; then
		log_event "event=blocked reason=recovery-lock-timeout lock=$LOCK_FILE"
		write_summary
		exit 75
	fi
	log_event "event=recovery-window result=reacquired"
}

cleanup()
{
	stop_servers
	rm -f "$root_source" "$peer_source" "$root_received" "$peer_received"
}

trap cleanup EXIT
trap 'log_event "event=stopped signal=INT"; write_summary; exit 130' INT
trap 'log_event "event=stopped signal=TERM"; write_summary; exit 143' TERM

ensure_servers()
{
	if [ -z "$root_http_pid" ] || ! kill -0 "$root_http_pid" 2>/dev/null; then
		python3 -m http.server 18081 --bind "$ROOT_IP" --directory /tmp \
			>>"$http_log" 2>&1 &
		root_http_pid=$!
	fi
	if [ -z "$peer_http_pid" ] || ! kill -0 "$peer_http_pid" 2>/dev/null; then
		ip netns exec "$PEER_NS" python3 -m http.server 18080 \
			--bind "$PEER_IP" --directory /tmp >>"$http_log" 2>&1 &
		peer_http_pid=$!
	fi
}

ping_batch()
{
	direction=$1
	shift
	output=$("$@" 2>&1)
	status=$?
	stats=$(printf '%s\n' "$output" |
		awk -F, '/packets transmitted/ {
			gsub(/^[[:space:]]+/, "", $1);
			gsub(/^[[:space:]]+/, "", $2);
			print $1 "," $2;
			exit
		}')
	[ -n "$stats" ] || stats=unavailable
	log_event "event=ping direction=$direction status=$status stats=$stats"
}

transfer_one_way()
{
	direction=$1
	source=$2
	destination=$3
	url=$4
	mode=$5

	rm -f "$source" "$destination"
	if ! dd if=/dev/urandom of="$source" bs=1M count="$TRANSFER_MIB" \
		status=none; then
		log_event "event=transfer direction=$direction result=source-failed"
		return 1
	fi
	source_hash=$(sha256sum "$source" | awk '{ print $1 }')
	if [ "$mode" = peer ]; then
		metrics=$(ip netns exec "$PEER_NS" curl --interface "$PEER_IP" \
			--connect-timeout 10 --max-time 300 --fail --silent \
			--show-error --output "$destination" \
			--write-out 'bytes=%{size_download},seconds=%{time_total},speed_Bps=%{speed_download}' \
			"$url" 2>&1)
		status=$?
	else
		metrics=$(curl --interface "$ROOT_IP" --connect-timeout 10 \
			--max-time 300 --fail --silent --show-error \
			--output "$destination" \
			--write-out 'bytes=%{size_download},seconds=%{time_total},speed_Bps=%{speed_download}' \
			"$url" 2>&1)
		status=$?
	fi
	if [ "$status" -ne 0 ]; then
		log_event "event=transfer direction=$direction result=failed status=$status detail=$metrics"
		return 1
	fi
	destination_hash=$(sha256sum "$destination" | awk '{ print $1 }')
	if [ "$source_hash" = "$destination_hash" ]; then
		result=ok
	else
		result=hash-mismatch
	fi
	log_event "event=transfer direction=$direction result=$result $metrics source_sha256=$source_hash destination_sha256=$destination_hash"
	[ "$result" = ok ]
}

write_summary()
{
	kernel_events=$(journalctl -k --since "$kernel_since" --no-pager 2>/dev/null |
		grep -Ei 'error -71|EPROTO|over.?current|under.?voltage|usb .*disconnect|usb .*reset|recoverable RX URB|transient RX URB submit error|USB TX URB error|read register .* (recovered|failed)|write register .* failed' || true)
	kernel_event_count=$(printf '%s\n' "$kernel_events" | sed '/^$/d' |
		awk 'END { print NR + 0 }')
	{
		printf 'mesh_soak_summary run_id=%s generated_utc=%s\n' \
			"$run_id" "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
		printf 'duration_requested_seconds=%s\n' "$DURATION_SECONDS"
		printf 'completed=%s\n' "$(grep -c 'event=complete$' "$log" || true)"
		printf 'state_total=%s\n' "$(grep -c 'event=state' "$log" || true)"
		printf 'state_established=%s\n' "$(grep -c 'event=state result=established' "$log" || true)"
		printf 'state_unavailable=%s\n' "$(grep -c 'event=state result=unavailable' "$log" || true)"
		printf 'ping_batches_total=%s\n' "$(grep -c 'event=ping' "$log" || true)"
		printf 'ping_batches_failed=%s\n' "$(grep 'event=ping' "$log" | grep -vc 'status=0' || true)"
		printf 'transfers_ok=%s\n' "$(grep -c 'event=transfer .*result=ok' "$log" || true)"
		printf 'transfers_failed=%s\n' "$(grep -cE 'event=transfer .*result=(failed|hash-mismatch|source-failed)' "$log" || true)"
		printf 'recovery_windows=%s\n' "$(grep -c 'event=recovery-window result=yield' "$log" || true)"
		printf 'invalidations=%s\n' "$(grep -c 'event=invalid' "$log" || true)"
		printf 'kernel_transport_events=%s\n' "$kernel_event_count"
		printf 'temperature_samples=%s\n' "$(grep -c 'event=state .*temp_millic=' "$log" || true)"
		printf 'temperature_min_millic=%s\n' "$(awk '
			/event=state/ {
				for (i = 1; i <= NF; i++)
					if ($i ~ /^temp_millic=[0-9]+$/) {
						split($i, value, "=");
						if (!seen++ || value[2] < min) min = value[2];
					}
			}
			END { print seen ? min : "unavailable" }
		' "$log")"
		printf 'temperature_max_millic=%s\n' "$(awk '
			/event=state/ {
				for (i = 1; i <= NF; i++)
					if ($i ~ /^temp_millic=[0-9]+$/) {
						split($i, value, "=");
						if (!seen++ || value[2] > max) max = value[2];
					}
			}
			END { print seen ? max : "unavailable" }
		' "$log")"
		printf '\nusb_topology:\n'
	lsusb -t 2>&1 || true
		printf '\npower_state:\n'
		vcgencmd get_throttled 2>&1 || true
		printf '\nkernel_transport_events_since_start:\n'
		printf '%s\n' "$kernel_events" | sed '/^$/d'
	} >"$summary"
	ln -sfn "$summary" "$LOG_DIR/latest-summary.log"
}

summary_functional_passes()
{
	completed=$(sed -n 's/^completed=//p' "$summary")
	state_total=$(sed -n 's/^state_total=//p' "$summary")
	state_established=$(sed -n 's/^state_established=//p' "$summary")
	state_unavailable=$(sed -n 's/^state_unavailable=//p' "$summary")
	ping_failed=$(sed -n 's/^ping_batches_failed=//p' "$summary")
	transfers_failed=$(sed -n 's/^transfers_failed=//p' "$summary")
	invalidations=$(sed -n 's/^invalidations=//p' "$summary")
	case $completed:$state_total:$state_established:$state_unavailable:$ping_failed:$transfers_failed:$invalidations in
		:*|*::*|*:|*[!0-9:]*) return 1 ;;
	esac
	[ "$completed" -eq 1 ] && [ "$state_total" -gt 0 ] &&
		[ "$state_total" -eq "$state_established" ] &&
		[ "$state_unavailable" -eq 0 ] && [ "$ping_failed" -eq 0 ] &&
		[ "$transfers_failed" -eq 0 ] && [ "$invalidations" -eq 0 ]
}

summary_requires_review()
{
	recovery_windows=$(sed -n 's/^recovery_windows=//p' "$summary")
	kernel_events=$(sed -n 's/^kernel_transport_events=//p' "$summary")
	case $recovery_windows:$kernel_events in
		:*|*::*|*:|*[!0-9:]*) return 0 ;;
	esac
	[ "$recovery_windows" -ne 0 ] || [ "$kernel_events" -ne 0 ]
}

log_event "event=start duration_seconds=$DURATION_SECONDS poll_seconds=$POLL_SECONDS transfer_seconds=$TRANSFER_SECONDS transfer_mib=$TRANSFER_MIB"

if ! command -v flock >/dev/null 2>&1; then
	log_event "event=blocked reason=flock-missing"
	write_summary
	exit 2
fi
if [ -n "${LOCK_FD_INHERITED:-}" ]; then
	if [ "$LOCK_FD_INHERITED" != 9 ] || [ ! -e "/proc/$$/fd/9" ] ||
	   ! flock -n 9; then
		log_event "event=blocked reason=inherited-test-lock-invalid"
		write_summary
		exit 75
	fi
else
	exec 9>"$LOCK_FILE"
	if ! flock -n 9; then
		log_event "event=blocked reason=test-lock-held lock=$LOCK_FILE"
		write_summary
		exit 75
	fi
fi

if secure_test_running; then
	log_event "event=blocked reason=secure-test-supplicant-running"
	write_summary
	exit 75
fi

root_if=$(find_root_if "$ROOT_MAC")
peer_if=$(find_peer_if "$PEER_MAC")
if [ -z "$root_if" ] || [ -z "$peer_if" ] ||
   ! open_topology_ready "$root_if" "$peer_if"; then
	log_event "event=blocked reason=open-topology-preflight-failed root_if=${root_if:-none} peer_if=${peer_if:-none}"
	write_summary
	exit 75
fi

log_event "event=preflight result=pass root_if=$root_if peer_if=$peer_if"

while [ "$(date +%s)" -lt "$end_epoch" ]; do
	if secure_test_running; then
		log_event "event=invalid reason=concurrent-secure-test-supplicant"
		write_summary
		exit 75
	fi
	root_if=$(find_root_if "$ROOT_MAC")
	peer_if=$(find_peer_if "$PEER_MAC")
	if [ -n "$root_if" ] && [ -n "$peer_if" ]; then
		if ! has_ipv4 root "$root_if" "$ROOT_IP" ||
		   ! has_ipv4 peer "$peer_if" "$PEER_IP" ||
		   [ "$(mesh_mfp root "$root_if")" != no ] ||
		   [ "$(mesh_mfp peer "$peer_if")" != no ]; then
			log_event "event=invalid reason=open-topology-invariant-failed root_if=$root_if peer_if=$peer_if"
			write_summary
			exit 75
		fi
		root_plink=$($IW dev "$root_if" station dump 2>/dev/null |
			awk '/mesh plink:/ { print $3; exit }')
		peer_plink=$(ip netns exec "$PEER_NS" $IW dev "$peer_if" \
			station dump 2>/dev/null | awk '/mesh plink:/ { print $3; exit }')
		root_paths=$($IW dev "$root_if" mpath dump 2>/dev/null |
			awk 'NR > 1 { count++ } END { print count + 0 }')
		peer_paths=$(ip netns exec "$PEER_NS" $IW dev "$peer_if" \
			mpath dump 2>/dev/null |
			awk 'NR > 1 { count++ } END { print count + 0 }')
		if [ "$root_plink" = ESTAB ] && [ "$peer_plink" = ESTAB ] &&
		   [ "$root_paths" -gt 0 ] && [ "$peer_paths" -gt 0 ]; then
			state=established
		else
			state=degraded
		fi
		temp_millic=$(read_temp_millic)
		throttled=$(read_throttled)
		log_event "event=state result=$state root_if=$root_if peer_if=$peer_if root_plink=${root_plink:-none} peer_plink=${peer_plink:-none} root_paths=$root_paths peer_paths=$peer_paths temp_millic=${temp_millic:-unavailable} throttled=${throttled:-unavailable}"
		case "$temp_millic" in
			*[!0-9]*|'') ;;
			*)
				if [ "$temp_millic" -ge "$MAX_TEMP_MILLIC" ]; then
					log_event "event=invalid reason=thermal-limit temp_millic=$temp_millic max_temp_millic=$MAX_TEMP_MILLIC"
					write_summary
					exit 75
				fi
				;;
		esac
		ping_batch root-to-peer ping -I "$root_if" -c 10 -W 1 "$PEER_IP"
		ping_batch peer-to-root ip netns exec "$PEER_NS" ping -I "$peer_if" \
			-c 10 -W 1 "$ROOT_IP"
		now=$(date +%s)
		if [ "$now" -ge "$next_transfer" ]; then
			ensure_servers
			sleep 1
			root_transfer=fail
			peer_transfer=fail
			if transfer_one_way root-to-peer "$root_source" "$peer_received" \
				"http://$ROOT_IP:18081/$(basename "$root_source")" peer; then
				root_transfer=ok
			fi
			if transfer_one_way peer-to-root "$peer_source" "$root_received" \
				"http://$PEER_IP:18080/$(basename "$peer_source")" root; then
				peer_transfer=ok
			fi
			if [ "$root_transfer" = ok ] && [ "$peer_transfer" = ok ]; then
				next_transfer=$((now + TRANSFER_SECONDS))
			else
				next_transfer=$((now + POLL_SECONDS))
				if [ -z "$(find_root_if "$ROOT_MAC")" ] ||
				   [ -z "$(find_peer_if "$PEER_MAC")" ]; then
					stop_servers
					yield_for_recovery
				fi
			fi
		fi
	else
		log_event "event=state result=unavailable root_if=${root_if:-none} peer_if=${peer_if:-none}"
		stop_servers
		yield_for_recovery
	fi
	sleep "$POLL_SECONDS"
done

log_event "event=complete"
write_summary
if ! summary_functional_passes; then
	exit 1
fi
if summary_requires_review; then
	exit 4
fi
exit 0
