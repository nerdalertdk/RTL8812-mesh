#!/bin/sh
# Report only the log and summary belonging to the current/latest soak run.

set -eu

LOG_DIR=${LOG_DIR:-/var/tmp/rtl8812au-mesh/mesh-soak}
latest=$LOG_DIR/latest.log

if [ ! -e "$latest" ]; then
	echo "no soak log at $latest" >&2
	exit 3
fi

log=$(readlink -f "$latest")
base=${log##*/}
case $base in
	soak-*.log) run_id=${base#soak-}; run_id=${run_id%.log} ;;
	*) echo "unexpected soak log name: $base" >&2; exit 3 ;;
esac
summary=$LOG_DIR/summary-$run_id.log
start_utc=$(awk '/event=start/ { print $1; exit }' "$log")
if [ -n "$start_utc" ] &&
   journalctl -k --since "$start_utc" --no-pager -n 1 >/dev/null 2>&1; then
	kernel_usb=$(journalctl -k --since "$start_utc" --no-pager 2>/dev/null |
		grep -Eic 'error -71|EPROTO|over.?current|under.?voltage|usb .*disconnect|usb .*reset|recoverable RX URB|transient RX URB submit error|read register .* (recovered|failed)|write register .* failed' || true)
else
	kernel_usb=unavailable
fi

awk -v run_id="$run_id" -v kernel_usb="$kernel_usb" '
	BEGIN {
		states = established = state_bad = 0
		root_pings = root_ping_bad = peer_pings = peer_ping_bad = 0
		transfers = transfer_bad = recoveries = invalid = samples = 0
	}
	/event=state / {
		states++
		if ($0 ~ /event=state result=established/)
			established++
		else
			state_bad++
		for (i = 1; i <= NF; i++) {
			if ($i ~ /^temp_millic=[0-9]+$/) {
				split($i, pair, "="); temp = pair[2] + 0
				if (!samples || temp < min_temp) min_temp = temp
				if (!samples || temp > max_temp) max_temp = temp
				samples++
			}
		}
	}
	/event=ping direction=root-to-peer/ {
		root_pings++
		if ($0 !~ / status=0( |$)/) root_ping_bad++
	}
	/event=ping direction=peer-to-root/ {
		peer_pings++
		if ($0 !~ / status=0( |$)/) peer_ping_bad++
	}
	/event=transfer / {
		transfers++
		if ($0 !~ / result=ok( |$)/) transfer_bad++
	}
	/event=recovery-window result=yield/ { recoveries++ }
	/event=invalid/ { invalid++ }
	END {
		bad = state_bad + root_ping_bad + peer_ping_bad + transfer_bad + invalid
		printf "run_id=%s states=%d established=%d state_bad=%d root_pings=%d root_ping_bad=%d peer_pings=%d peer_ping_bad=%d transfers=%d transfer_bad=%d invalid=%d recoveries=%d bad=%d kernel_usb_events=%s", run_id, states, established, state_bad, root_pings, root_ping_bad, peer_pings, peer_ping_bad, transfers, transfer_bad, invalid, recoveries, bad, kernel_usb
		if (samples)
			printf " temp_millic_min=%d temp_millic_max=%d", min_temp, max_temp
		printf "\n"
	}
' "$log"

if [ -r "$summary" ]; then
	echo "state=complete summary=$summary"
	cat "$summary"
else
	echo "state=running summary=pending"
	tail -5 "$log"
fi
