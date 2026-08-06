#!/bin/sh
# Build, but never install or load, an exact source tree after clean finalization.

set -eu

FINALIZER_UNIT=${FINALIZER_UNIT:?set FINALIZER_UNIT}
FINALIZER_INVOCATION_ID=${FINALIZER_INVOCATION_ID:?set FINALIZER_INVOCATION_ID}
SOAK_SUMMARY=${SOAK_SUMMARY:?set the exact soak summary path}
SOAK_RUN_ID=${SOAK_RUN_ID:?set the exact soak run ID}
TRANSFER_LOG_DIR=${TRANSFER_LOG_DIR:?set the final transfer log directory}
SOURCE_DIR=${SOURCE_DIR:?set the exact source directory}
SOURCE_MANIFEST=${SOURCE_MANIFEST:?set the expected root build-input manifest}
PACKAGE_NAME=${PACKAGE_NAME:-rtl8812au-mesh}
PACKAGE_VERSION=${PACKAGE_VERSION:-0.1.5}
FILE_MIB=${FILE_MIB:-512}
WAIT_SECONDS=${WAIT_SECONDS:-30}
MAX_WAIT_SECONDS=${MAX_WAIT_SECONDS:-36000}
BUILD_JOBS=${BUILD_JOBS:-2}
LOCK_FILE=${LOCK_FILE:-/run/lock/rtw88-dkms-build.lock}
RESULT_DIR=${RESULT_DIR:-/var/tmp/rtl8812au-mesh/post-soak-build}
DKMS=${DKMS:-/usr/sbin/dkms}
PREFLIGHT_ONLY=${PREFLIGHT_ONLY:-0}
modules='rtw_core rtw_usb rtw_88xxa rtw_8812a rtw_8812au'
kernel=$(uname -r)
arch=$(uname -m)
dkms_source=/usr/src/$PACKAGE_NAME-$PACKAGE_VERSION

[ "$(id -u)" -eq 0 ] || { echo "run this build gate as root" >&2; exit 2; }
for value in "$FILE_MIB" "$WAIT_SECONDS" "$MAX_WAIT_SECONDS" "$BUILD_JOBS"; do
	case $value in *[!0-9]*|''|0) echo "numeric settings must be positive integers" >&2; exit 2 ;; esac
done
case $PREFLIGHT_ONLY in 0|1) ;; *) echo "PREFLIGHT_ONLY must be 0 or 1" >&2; exit 2 ;; esac
case $SOAK_RUN_ID in *[!0-9TZ]*|'') echo "invalid soak run ID" >&2; exit 2 ;; esac
case $FINALIZER_INVOCATION_ID in *[!0-9a-f]*|'') echo "invalid invocation ID" >&2; exit 2 ;; esac
[ -d "$SOURCE_DIR" ] || { echo "source directory is unavailable" >&2; exit 2; }
[ -x "$DKMS" ] || { echo "dkms is required at $DKMS" >&2; exit 2; }
for command in flock make modinfo sha256sum systemctl; do
	command -v "$command" >/dev/null 2>&1 || { echo "$command is required" >&2; exit 2; }
done

source_manifest()
{
	(
		cd "$SOURCE_DIR"
		find . -maxdepth 1 -type f \
			\( -name '*.c' -o -name '*.h' -o -name Makefile -o -name dkms.conf \) \
			-print0 | sort -z | xargs -0 sha256sum | sha256sum |
			awk '{ print $1 }'
	)
}

[ "$(source_manifest)" = "$SOURCE_MANIFEST" ] || {
	echo "source manifest mismatch" >&2
	exit 1
}
[ ! -e "$dkms_source" ] || { echo "DKMS source destination already exists" >&2; exit 1; }
if $DKMS status "$PACKAGE_NAME/$PACKAGE_VERSION" 2>/dev/null | grep -q .; then
	echo "DKMS $PACKAGE_NAME/$PACKAGE_VERSION is already registered" >&2
	exit 1
fi
current_invocation=$(systemctl show "$FINALIZER_UNIT" -p InvocationID --value 2>/dev/null || true)
[ "$current_invocation" = "$FINALIZER_INVOCATION_ID" ] || {
	echo "finalizer invocation mismatch" >&2
	exit 1
}
preexisting_transfers=$(find "$TRANSFER_LOG_DIR" -maxdepth 1 -type f \
	-name 'transfer-*.log' -print 2>/dev/null | awk 'END { print NR + 0 }')
[ "$preexisting_transfers" -eq 0 ] || {
	echo "final transfer directory is not empty before finalization" >&2
	exit 1
}

if [ "$PREFLIGHT_ONLY" -eq 1 ]; then
	printf 'result=preflight-pass source_manifest=%s finalizer_invocation=%s dkms_version_absent=1\n' \
		"$SOURCE_MANIFEST" "$current_invocation"
	exit 0
fi

elapsed=0
while systemctl is-active --quiet "$FINALIZER_UNIT"; do
	if [ "$elapsed" -ge "$MAX_WAIT_SECONDS" ]; then
		echo "timed out waiting for $FINALIZER_UNIT" >&2
		exit 1
	fi
	sleep "$WAIT_SECONDS"
	elapsed=$((elapsed + WAIT_SECONDS))
done

current_invocation=$(systemctl show "$FINALIZER_UNIT" -p InvocationID --value 2>/dev/null || true)
result=$(systemctl show "$FINALIZER_UNIT" -p Result --value 2>/dev/null || true)
status=$(systemctl show "$FINALIZER_UNIT" -p ExecMainStatus --value 2>/dev/null || true)
[ "$current_invocation" = "$FINALIZER_INVOCATION_ID" ] &&
	[ "$result" = success ] && [ "$status" = 0 ] || {
	echo "exact finalizer did not pass: invocation=$current_invocation result=$result status=$status" >&2
	exit 1
}

[ -r "$SOAK_SUMMARY" ] || { echo "exact soak summary is unavailable" >&2; exit 1; }
case $(sed -n '1p' "$SOAK_SUMMARY") in
	"mesh_soak_summary run_id=$SOAK_RUN_ID "*) ;;
	*) echo "soak summary run ID mismatch" >&2; exit 1 ;;
esac
field()
{
	sed -n "s/^$1=//p" "$SOAK_SUMMARY"
}
completed=$(field completed)
state_total=$(field state_total)
state_established=$(field state_established)
state_unavailable=$(field state_unavailable)
ping_failed=$(field ping_batches_failed)
transfers_failed=$(field transfers_failed)
invalidations=$(field invalidations)
recoveries=$(field recovery_windows)
kernel_events=$(field kernel_transport_events)
values=$completed:$state_total:$state_established:$state_unavailable
values=$values:$ping_failed:$transfers_failed:$invalidations
values=$values:$recoveries:$kernel_events
case $values in :*|*::*|*:|*[!0-9:]*) echo "malformed soak summary" >&2; exit 1 ;; esac
[ "$completed" -eq 1 ] && [ "$state_total" -gt 0 ] &&
	[ "$state_total" -eq "$state_established" ] &&
	[ "$state_unavailable" -eq 0 ] && [ "$ping_failed" -eq 0 ] &&
	[ "$transfers_failed" -eq 0 ] && [ "$invalidations" -eq 0 ] &&
	[ "$recoveries" -eq 0 ] && [ "$kernel_events" -eq 0 ] || {
	echo "soak summary is not clean" >&2
	exit 1
}

latest_transfer=$(find "$TRANSFER_LOG_DIR" -maxdepth 1 -type f \
	-name 'transfer-*.log' -printf '%T@ %p\n' 2>/dev/null |
	sort -nr | sed -n '1s/^[^ ]* //p')
[ -n "$latest_transfer" ] && [ -r "$latest_transfer" ] || {
	echo "final transfer result is unavailable" >&2
	exit 1
}
grep -q "event=start file_mib=$FILE_MIB " "$latest_transfer"
[ "$(grep -c 'event=transfer direction=root-to-peer result=ok ' "$latest_transfer")" -eq 1 ]
[ "$(grep -c 'event=transfer direction=peer-to-root result=ok ' "$latest_transfer")" -eq 1 ]
[ "$(grep -c 'event=complete result=pass kernel_events=0 ' "$latest_transfer")" -eq 1 ]

[ "$(source_manifest)" = "$SOURCE_MANIFEST" ] || {
	echo "source changed while waiting" >&2
	exit 1
}
exec 9>"$LOCK_FILE"
flock -n 9 || { echo "another DKMS build holds $LOCK_FILE" >&2; exit 75; }
[ ! -e "$dkms_source" ] || { echo "DKMS source appeared while waiting" >&2; exit 1; }
if $DKMS status "$PACKAGE_NAME/$PACKAGE_VERSION" 2>/dev/null | grep -q .; then
	echo "DKMS version appeared while waiting" >&2
	exit 1
fi

mkdir -p "$RESULT_DIR"
run_id=$(date -u +%Y%m%dT%H%M%SZ)
result_log=$RESULT_DIR/build-$run_id.log
warning_log=$RESULT_DIR/build-$run_id-W1.log
warning_source=$RESULT_DIR/source-$PACKAGE_VERSION-W1-$run_id
exec >"$result_log" 2>&1
printf 'event=start package=%s version=%s kernel=%s arch=%s source_manifest=%s ' \
	"$PACKAGE_NAME" "$PACKAGE_VERSION" "$kernel" "$arch" "$SOURCE_MANIFEST"
printf 'finalizer_invocation=%s transfer_log=%s\n' \
	"$FINALIZER_INVOCATION_ID" "$latest_transfer"

mkdir "$warning_source"
cp -a "$SOURCE_DIR/." "$warning_source/"
if ! make -C "$warning_source" KVER="$kernel" JOBS="$BUILD_JOBS" W=1 all \
	>"$warning_log" 2>&1; then
	cat "$warning_log"
	echo "event=W1-build result=failed"
	exit 1
fi
cat "$warning_log"
if grep -Eiq '(^|[[:space:]])(warning|error):' "$warning_log"; then
	echo "event=W1-build result=diagnostic-found"
	exit 1
fi
w1_count=0
for module in $modules; do
	[ -s "$warning_source/$module.ko" ] || { echo "missing W=1 module $module"; exit 1; }
	w1_count=$((w1_count + 1))
done
printf 'event=W1-build result=pass modules=%s warnings=0\n' "$w1_count"

mkdir "$dkms_source"
cp -a "$SOURCE_DIR/." "$dkms_source/"
$DKMS add -m "$PACKAGE_NAME" -v "$PACKAGE_VERSION"
$DKMS build -m "$PACKAGE_NAME" -v "$PACKAGE_VERSION" -k "$kernel"
dkms_line=$($DKMS status "$PACKAGE_NAME/$PACKAGE_VERSION" -k "$kernel" |
	grep -F "$PACKAGE_NAME/$PACKAGE_VERSION, $kernel, $arch: built" || true)
[ -n "$dkms_line" ] || { echo "DKMS did not report exact built state"; exit 1; }

module_dir=/var/lib/dkms/$PACKAGE_NAME/$PACKAGE_VERSION/$kernel/$arch/module
dkms_count=0
for module in $modules; do
	artifact=$module_dir/$module.ko
	[ -s "$artifact" ] || { echo "missing DKMS module $module"; exit 1; }
	set -- $(modinfo -F vermagic "$artifact")
	[ "${1:-}" = "$kernel" ] || { echo "$module vermagic mismatch: $*"; exit 1; }
	hash=$(sha256sum "$artifact" | awk '{ print $1 }')
	srcversion=$(modinfo -F srcversion "$artifact")
	printf 'module=%s srcversion=%s sha256=%s path=%s\n' \
		"$module" "$srcversion" "$hash" "$artifact"
	dkms_count=$((dkms_count + 1))
done
[ "$dkms_count" -eq 5 ]
printf 'event=complete result=pass W1_modules=%s DKMS_modules=%s action=build-only result_log=%s\n' \
	"$w1_count" "$dkms_count" "$result_log"
