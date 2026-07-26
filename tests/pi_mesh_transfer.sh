#!/bin/sh
# Bidirectional checksummed transfer gate for an established open mesh.

set -eu

IW=${IW:-/usr/sbin/iw}
ROOT_MAC=${ROOT_MAC:?set ROOT_MAC to the primary adapter MAC}
PEER_MAC=${PEER_MAC:?set PEER_MAC to the peer adapter MAC}
PEER_NS=${PEER_NS:-meshpeer}
ROOT_IP=${ROOT_IP:-10.44.0.1}
PEER_IP=${PEER_IP:-10.44.0.2}
FILE_MIB=${FILE_MIB:-512}
LOG_DIR=${LOG_DIR:-/var/tmp/rtl8812au-mesh/mesh-transfer}
LOCK_FILE=${LOCK_FILE:-/run/lock/rtw88-mesh-test.lock}
MAX_TIME=${MAX_TIME:-3600}

if command -v flock >/dev/null 2>&1; then
	exec 9>"$LOCK_FILE"
	if ! flock -n 9; then
		echo "another rtw88 mesh test holds $LOCK_FILE" >&2
		exit 75
	fi
fi

find_root_if()
{
	ip -o link 2>/dev/null | awk -v mac="$ROOT_MAC" '
		tolower($0) ~ tolower(mac) { sub(/:$/, "", $2); print $2; exit }
	'
}

find_peer_if()
{
	ip netns exec "$PEER_NS" ip -o link 2>/dev/null |
		awk -v mac="$PEER_MAC" '
			tolower($0) ~ tolower(mac) {
				sub(/:$/, "", $2); print $2; exit
			}
		'
}

ns()
{
	ip netns exec "$PEER_NS" "$@"
}

ROOT_IF=$(find_root_if)
PEER_IF=$(find_peer_if)
if [ -z "$ROOT_IF" ] || [ -z "$PEER_IF" ]; then
	echo "mesh interfaces not found root=${ROOT_IF:-none} peer=${PEER_IF:-none}" >&2
	exit 1
fi

if ! $IW dev "$ROOT_IF" station dump | grep -q 'mesh plink:[[:space:]]*ESTAB' ||
   ! ns $IW dev "$PEER_IF" station dump | grep -q 'mesh plink:[[:space:]]*ESTAB'; then
	echo "mesh peer link is not established in both directions" >&2
	exit 1
fi

mkdir -p "$LOG_DIR"
available_kib=$(df -Pk "$LOG_DIR" | awk 'NR == 2 { print $4 }')
required_kib=$((FILE_MIB * 1024 * 3 + 102400))
if [ -z "$available_kib" ] || [ "$available_kib" -lt "$required_kib" ]; then
	echo "insufficient space: available_kib=${available_kib:-unknown} required_kib=$required_kib" >&2
	exit 1
fi
run_id=$(date -u +%Y%m%dT%H%M%SZ)
result=$LOG_DIR/transfer-$run_id.log
source_file=$LOG_DIR/source-$run_id.bin
peer_received=$LOG_DIR/peer-received-$run_id.bin
root_received=$LOG_DIR/root-received-$run_id.bin
http_log=$LOG_DIR/http-$run_id.log
root_http_pid=
peer_http_pid=
start_epoch=$(date +%s)

cleanup()
{
	for pid in "$root_http_pid" "$peer_http_pid"; do
		if [ -n "$pid" ]; then
			# ip-netns may retain a wrapper process around the server. Stop
			# children before the wrapper, then reap the background job.
			pkill -TERM -P "$pid" 2>/dev/null || true
			kill "$pid" 2>/dev/null || true
			wait "$pid" 2>/dev/null || true
		fi
	done
	rm -f -- "$source_file" "$peer_received" "$root_received"
}
trap cleanup EXIT
trap 'exit 130' INT TERM

log()
{
	printf '%s %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$*" |
		tee -a "$result"
}

log "event=start file_mib=$FILE_MIB root_if=$ROOT_IF peer_if=$PEER_IF"
if ! dd if=/dev/urandom of="$source_file" bs=1M count="$FILE_MIB" \
	status=none; then
	log "event=source result=failed"
	exit 1
fi
source_hash=$(sha256sum "$source_file" | awk '{ print $1 }')
log "event=source result=ok bytes=$((FILE_MIB * 1024 * 1024)) sha256=$source_hash"

python3 -m http.server 18081 --bind "$ROOT_IP" --directory "$LOG_DIR" 9>&- \
	>>"$http_log" 2>&1 &
root_http_pid=$!
ns python3 -m http.server 18080 --bind "$PEER_IP" --directory "$LOG_DIR" 9>&- \
	>>"$http_log" 2>&1 &
peer_http_pid=$!

source_name=$(basename "$source_file")
root_url=http://$ROOT_IP:18081/$source_name
peer_url=http://$PEER_IP:18080/$source_name

# Server creation and cold HWMP path discovery are asynchronous. Do not turn a
# startup race into a transfer failure: require both processes to remain alive
# and prove each HTTP endpoint is reachable from the opposite mesh endpoint.
http_ready=false
attempt=1
while [ "$attempt" -le 20 ]; do
	if ! kill -0 "$root_http_pid" 2>/dev/null ||
	   ! kill -0 "$peer_http_pid" 2>/dev/null; then
		break
	fi
	if ns curl --interface "$PEER_IP" --connect-timeout 2 --max-time 3 \
		--fail --silent --head "$root_url" >/dev/null 2>&1 &&
	   curl --interface "$ROOT_IP" --connect-timeout 2 --max-time 3 \
		--fail --silent --head "$peer_url" >/dev/null 2>&1; then
		http_ready=true
		break
	fi
	attempt=$((attempt + 1))
	sleep 1
done
if [ "$http_ready" != true ]; then
	detail=$(tail -20 "$http_log" 2>/dev/null | tr '\n' ';')
	log "event=http-readiness result=failed attempts=$attempt detail=${detail:-none}"
	exit 1
fi
log "event=http-readiness result=pass attempts=$attempt"

metrics=$(ns curl --interface "$PEER_IP" --connect-timeout 10 \
	--max-time "$MAX_TIME" --fail --silent --show-error \
	--output "$peer_received" \
	--write-out 'bytes=%{size_download},seconds=%{time_total},speed_Bps=%{speed_download}' \
	"$root_url" 2>&1) || {
	status=$?
	log "event=transfer direction=root-to-peer result=failed status=$status detail=$metrics"
	exit 1
}
peer_hash=$(sha256sum "$peer_received" | awk '{ print $1 }')
if [ "$peer_hash" != "$source_hash" ]; then
	log "event=transfer direction=root-to-peer result=hash-mismatch $metrics source_sha256=$source_hash destination_sha256=$peer_hash"
	exit 1
fi
log "event=transfer direction=root-to-peer result=ok $metrics sha256=$peer_hash"

metrics=$(curl --interface "$ROOT_IP" --connect-timeout 10 \
	--max-time "$MAX_TIME" --fail --silent --show-error \
	--output "$root_received" \
	--write-out 'bytes=%{size_download},seconds=%{time_total},speed_Bps=%{speed_download}' \
	"$peer_url" 2>&1) || {
	status=$?
	log "event=transfer direction=peer-to-root result=failed status=$status detail=$metrics"
	exit 1
}
root_hash=$(sha256sum "$root_received" | awk '{ print $1 }')
if [ "$root_hash" != "$source_hash" ]; then
	log "event=transfer direction=peer-to-root result=hash-mismatch $metrics source_sha256=$source_hash destination_sha256=$root_hash"
	exit 1
fi
log "event=transfer direction=peer-to-root result=ok $metrics sha256=$root_hash"

root_paths=$($IW dev "$ROOT_IF" mpath dump 2>/dev/null |
	awk 'NR > 1 { count++ } END { print count + 0 }')
peer_paths=$(ns $IW dev "$PEER_IF" mpath dump 2>/dev/null |
	awk 'NR > 1 { count++ } END { print count + 0 }')
if [ "$root_paths" -eq 0 ] || [ "$peer_paths" -eq 0 ]; then
	log "event=postflight result=failed root_paths=$root_paths peer_paths=$peer_paths"
	exit 1
fi
log "event=postflight result=pass root_paths=$root_paths peer_paths=$peer_paths"
log "event=complete elapsed_s=$(( $(date +%s) - start_epoch ))"
printf '# kernel-transport-events-since-start\n' | tee -a "$result"
journalctl -k --since "@$start_epoch" --no-pager 2>/dev/null |
	grep -Ei 'error -71|EPROTO|over.?current|under.?voltage|usb .*disconnect|usb .*reset|recoverable RX URB' |
	tee -a "$result" || true
