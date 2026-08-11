#!/bin/sh
# Exercise the soak/finalizer summary filename and field contract offline.

set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
repo_dir=$(dirname "$script_dir")
tmp_dir=$(mktemp -d /tmp/rtl8812au-soak-finalizer-check-XXXXXX)
trap 'rm -rf -- "$tmp_dir"' EXIT INT TERM

run_id=20260806T183421Z
mkdir -p "$tmp_dir/bin" "$tmp_dir/soak"

cat >"$tmp_dir/bin/systemctl" <<'EOF'
#!/bin/sh
case ${1:-} in
	is-active) exit 3 ;;
	*) exit 2 ;;
esac
EOF
chmod +x "$tmp_dir/bin/systemctl"

cat >"$tmp_dir/bin/id" <<'EOF'
#!/bin/sh
[ "${1:-}" = -u ] && { echo 0; exit 0; }
exit 2
EOF
chmod +x "$tmp_dir/bin/id"

cat >"$tmp_dir/transfer" <<'EOF'
#!/bin/sh
echo "transfer_fixture=executed"
EOF
chmod +x "$tmp_dir/transfer"

cat >"$tmp_dir/soak/summary-$run_id.log" <<EOF
mesh_soak_summary run_id=$run_id generated_utc=2026-08-07T02:34:55Z
duration_requested_seconds=28800
completed=1
state_total=597
state_established=597
state_unavailable=0
ping_batches_total=1194
ping_batches_failed=0
transfers_ok=16
transfers_failed=0
recovery_windows=0
invalidations=0
kernel_transport_events=0
EOF

output=$(PATH="$tmp_dir/bin:$PATH" \
	SOAK_UNIT=fixture-soak.service \
	SOAK_LOG_DIR="$tmp_dir/soak" \
	SOAK_RUN_ID=$run_id \
	TRANSFER_TEST="$tmp_dir/transfer" \
	WAIT_SECONDS=1 MAX_WAIT_SECONDS=1 \
	"$repo_dir/tests/pi_mesh_soak_finalize.sh")

printf '%s\n' "$output" | grep -q '^soak summary passed; starting final integrity transfer$'
printf '%s\n' "$output" | grep -q '^transfer_fixture=executed$'

echo "soak_finalizer=summary-name-match fields=valid transfer=executed"
