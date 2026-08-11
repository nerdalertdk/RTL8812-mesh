#!/bin/sh
# Build exact RTL8812AU source with W=1 and DKMS; never install or load it.

set -eu

SOURCE_DIR=${SOURCE_DIR:?set the exact flat source directory}
SOURCE_MANIFEST=${SOURCE_MANIFEST:?set the expected build-input manifest}
SOURCE_COMMIT=${SOURCE_COMMIT:?set the source commit identifier}
PACKAGE_NAME=${PACKAGE_NAME:-rtl8812au-mesh}
PACKAGE_VERSION=${PACKAGE_VERSION:-0.1.5}
BUILD_JOBS=${BUILD_JOBS:-2}
LOCK_FILE=${LOCK_FILE:-/run/lock/rtw88-dkms-build.lock}
RESULT_DIR=${RESULT_DIR:-/var/tmp/rtl8812au-mesh/dkms-build-only}
DKMS=${DKMS:-/usr/sbin/dkms}
modules='rtw_core rtw_usb rtw_88xxa rtw_8812a rtw_8812au'
kernel=$(uname -r)
arch=$(uname -m)
dkms_source=/usr/src/$PACKAGE_NAME-$PACKAGE_VERSION

[ "$(id -u)" -eq 0 ] || { echo "run this build gate as root" >&2; exit 2; }
case $BUILD_JOBS in *[!0-9]*|''|0) echo "BUILD_JOBS must be positive" >&2; exit 2 ;; esac
case $SOURCE_COMMIT in *[!0-9a-f]*|'') echo "invalid SOURCE_COMMIT" >&2; exit 2 ;; esac
[ -d "$SOURCE_DIR" ] || { echo "source directory is unavailable" >&2; exit 2; }
[ -x "$DKMS" ] || { echo "dkms is required at $DKMS" >&2; exit 2; }
for command in flock make modinfo sha256sum; do
	command -v "$command" >/dev/null 2>&1 || {
		echo "$command is required" >&2
		exit 2
	}
done

source_manifest()
{
	(
		cd "$SOURCE_DIR"
		find . -maxdepth 1 -type f \
			\( -name '*.c' -o -name '*.h' -o -name Makefile -o -name dkms.conf \) \
			-print0 | LC_ALL=C sort -z | xargs -0 sha256sum | sha256sum |
			awk '{ print $1 }'
	)
}

# The staged build input is deliberately flat and contains no agent context,
# repository metadata, credentials, generated modules, or unrelated assets.
unexpected=$(find "$SOURCE_DIR" -mindepth 1 -maxdepth 1 \
	\( ! -type f -o -type f \
	! \( -name '*.c' -o -name '*.h' -o -name Makefile -o -name dkms.conf \) \) \
	-print)
[ -z "$unexpected" ] || {
	echo "unexpected staged source entries:" >&2
	printf '%s\n' "$unexpected" >&2
	exit 2
}

actual_manifest=$(source_manifest)
[ "$actual_manifest" = "$SOURCE_MANIFEST" ] || {
	echo "source manifest mismatch expected=$SOURCE_MANIFEST actual=$actual_manifest" >&2
	exit 1
}
grep -q '^PACKAGE_NAME="'"$PACKAGE_NAME"'"$' "$SOURCE_DIR/dkms.conf"
grep -q '^PACKAGE_VERSION="'"$PACKAGE_VERSION"'"$' "$SOURCE_DIR/dkms.conf"

exec 9>"$LOCK_FILE"
flock -n 9 || { echo "another DKMS build holds $LOCK_FILE" >&2; exit 75; }
[ ! -e "$dkms_source" ] || { echo "DKMS source destination already exists" >&2; exit 1; }
if $DKMS status "$PACKAGE_NAME/$PACKAGE_VERSION" 2>/dev/null | grep -q .; then
	echo "DKMS $PACKAGE_NAME/$PACKAGE_VERSION is already registered" >&2
	exit 1
fi

actual_manifest=$(source_manifest)
[ "$actual_manifest" = "$SOURCE_MANIFEST" ] || {
	echo "source changed before build expected=$SOURCE_MANIFEST actual=$actual_manifest" >&2
	exit 1
}

mkdir -p "$RESULT_DIR"
run_id=$(date -u +%Y%m%dT%H%M%SZ)
result_log=$RESULT_DIR/build-$run_id.log
warning_log=$RESULT_DIR/build-$run_id-W1.log
warning_source=$RESULT_DIR/source-$PACKAGE_VERSION-W1-$run_id
exec >"$result_log" 2>&1

printf 'event=start package=%s version=%s kernel=%s arch=%s ' \
	"$PACKAGE_NAME" "$PACKAGE_VERSION" "$kernel" "$arch"
printf 'source_commit=%s source_manifest=%s action=build-only\n' \
	"$SOURCE_COMMIT" "$SOURCE_MANIFEST"

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
	[ -s "$warning_source/$module.ko" ] || {
		echo "missing W=1 module $module"
		exit 1
	}
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
	# Debian DKMS may compress its build artifacts before installation.  modinfo
	# reads either representation, so require exactly one supported artifact.
	if [ ! -s "$artifact" ]; then
		artifact=$module_dir/$module.ko.xz
	fi
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

actual_manifest=$(source_manifest)
[ "$actual_manifest" = "$SOURCE_MANIFEST" ] || {
	echo "source changed during build expected=$SOURCE_MANIFEST actual=$actual_manifest"
	exit 1
}
printf 'event=complete result=pass W1_modules=%s DKMS_modules=%s action=build-only result_log=%s\n' \
	"$w1_count" "$dkms_count" "$result_log"
