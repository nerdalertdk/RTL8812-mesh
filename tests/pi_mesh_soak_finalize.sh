#!/bin/sh
# Wait for a detached soak, validate its summary, then run final integrity.

set -eu

SOAK_UNIT=${SOAK_UNIT:?set the active systemd soak unit name}
SOAK_LOG_DIR=${SOAK_LOG_DIR:?set the soak LOG_DIR}
SOAK_RUN_ID=${SOAK_RUN_ID:?set the exact soak run ID}
TRANSFER_TEST=${TRANSFER_TEST:?set the absolute pi_mesh_transfer.sh path}
WAIT_SECONDS=${WAIT_SECONDS:-30}
MAX_WAIT_SECONDS=${MAX_WAIT_SECONDS:-32400}

[ "$(id -u)" -eq 0 ] || { echo "run this finalizer as root" >&2; exit 2; }
[ -x "$TRANSFER_TEST" ] || { echo "not executable: $TRANSFER_TEST" >&2; exit 2; }
case $WAIT_SECONDS:$MAX_WAIT_SECONDS in
	*[!0-9:]*|0:*|*:0) echo "wait intervals must be positive integers" >&2; exit 2 ;;
esac
case $SOAK_RUN_ID in
	*[!0-9TZ]*) echo "invalid soak run ID: $SOAK_RUN_ID" >&2; exit 2 ;;
esac

elapsed=0
while systemctl is-active --quiet "$SOAK_UNIT"; do
	if [ "$elapsed" -ge "$MAX_WAIT_SECONDS" ]; then
		echo "timed out waiting for $SOAK_UNIT" >&2
		exit 1
	fi
	sleep "$WAIT_SECONDS"
	elapsed=$((elapsed + WAIT_SECONDS))
done

summary=$SOAK_LOG_DIR/soak-$SOAK_RUN_ID-summary.log
[ -r "$summary" ] || {
	echo "matching soak summary is unavailable" >&2
	exit 1
}
expected_header="mesh_soak_summary run_id=$SOAK_RUN_ID "
case $(sed -n '1p' "$summary") in
	"$expected_header"*) ;;
	*) echo "soak summary run ID mismatch: $summary" >&2; exit 1 ;;
esac

field()
{
	sed -n "s/^$1=//p" "$summary"
}

completed=$(field completed)
state_total=$(field state_total)
state_established=$(field state_established)
state_unavailable=$(field state_unavailable)
ping_failed=$(field ping_batches_failed)
transfers_failed=$(field transfers_failed)
invalidations=$(field invalidations)
recovery_windows=$(field recovery_windows)
kernel_events=$(field kernel_transport_events)

values=$completed:$state_total:$state_established:$state_unavailable:$ping_failed:$transfers_failed:$invalidations:$recovery_windows:$kernel_events
case $values in
	:*|*::*|*:|*[!0-9:]*) echo "malformed soak summary: $summary" >&2; exit 1 ;;
esac
if [ "$completed" -ne 1 ] || [ "$state_total" -eq 0 ] ||
   [ "$state_total" -ne "$state_established" ] ||
   [ "$state_unavailable" -ne 0 ] || [ "$ping_failed" -ne 0 ] ||
   [ "$transfers_failed" -ne 0 ] || [ "$invalidations" -ne 0 ] ||
   [ "$recovery_windows" -ne 0 ] || [ "$kernel_events" -ne 0 ]; then
	echo "soak summary did not pass cleanly: $summary" >&2
	exit 1
fi

echo "soak summary passed; starting final integrity transfer"
exec "$TRANSFER_TEST"
