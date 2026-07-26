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

awk -v run_id="$run_id" '
	BEGIN {
		states = root_pings = peer_pings = transfers = 0
		bad = recoveries = usb = samples = 0
	}
	/event=state result=established/ {
		states++
		for (i = 1; i <= NF; i++) {
			if ($i ~ /^temp_millic=[0-9]+$/) {
				split($i, pair, "="); temp = pair[2] + 0
				if (!samples || temp < min_temp) min_temp = temp
				if (!samples || temp > max_temp) max_temp = temp
				samples++
			}
		}
	}
	/event=ping direction=root-to-peer status=0/ { root_pings++ }
	/event=ping direction=peer-to-root status=0/ { peer_pings++ }
	/event=transfer .* result=ok/ { transfers++ }
	/result=(failed|unavailable)|event=invalid/ { bad++ }
	/event=recovery/ { recoveries++ }
	/error -71|EPROTO|over.?current|usb .*disconnect|usb .*reset/ { usb++ }
	END {
		printf "run_id=%s established=%d root_pings=%d peer_pings=%d transfers_ok=%d bad=%d recoveries=%d usb_events=%d", run_id, states, root_pings, peer_pings, transfers, bad, recoveries, usb
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
