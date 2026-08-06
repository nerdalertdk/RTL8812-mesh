#!/bin/sh
# Ensure hardware gates cannot silently omit a known USB or power signature.

set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
repo_dir=$(dirname "$script_dir")
test_dir=$repo_dir/tests

functional_scripts='pi_mesh_channel_sweep.sh
pi_mesh_churn.sh
pi_mesh_multicast_probe.sh
pi_mesh_soak.sh
pi_mesh_soak_status.sh
pi_mesh_transfer.sh
pi_secure_mesh.sh
pi_usb_ctrl_stress.sh
pi_usb_tx_teardown_test.sh
pi_usb_tx_failure_test.sh'

required_patterns='error -71
EPROTO
over.?current
under.?voltage
usb .*disconnect
usb .*reset
recoverable RX URB
transient RX URB submit error
USB TX URB error
read register .* (recovered|failed)
write register .* failed'

failed=0
printf '%s\n' "$functional_scripts" | while IFS= read -r name; do
	[ -n "$name" ] || continue
	path=$test_dir/$name
	[ -r "$path" ] || {
		echo "missing hardware gate: $path" >&2
		exit 1
	}
	printf '%s\n' "$required_patterns" | while IFS= read -r pattern; do
		[ -n "$pattern" ] || continue
		grep -Fq "$pattern" "$path" || {
			echo "$name omits event signature: $pattern" >&2
			exit 1
		}
	done
done || failed=1

matrix_runner=$test_dir/pi_usb_path_trial.sh
for pattern in 'USB TX URB error' 'recoverable RX URB' \
	'transient RX URB submit error' 'under.?voltage' 'over.?current'; do
	grep -Fq "$pattern" "$matrix_runner" || {
		echo "pi_usb_path_trial.sh omits classified signature: $pattern" >&2
		failed=1
	}
done

[ "$failed" -eq 0 ] || exit 1
echo "functional_gates=10 transport_and_power_signatures=complete matrix_classification=complete"
