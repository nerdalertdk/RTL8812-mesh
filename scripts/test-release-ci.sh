#!/bin/sh
# Exercise the release archive and DKMS build steps in Debian Trixie AMD64.

set -eu

repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
platform=${DOCKER_PLATFORM:-linux/amd64}
output_dir=$(mktemp -d "${TMPDIR:-/tmp}/rtl8812au-release-ci.XXXXXX")
trap 'rm -rf "$output_dir"' EXIT HUP INT TERM

command -v docker >/dev/null || {
	echo "docker is required for the local release CI check" >&2
	exit 2
}

docker run --rm --platform "$platform" \
	-v "$repo_dir:/src:ro" -v "$output_dir:/out" \
	debian:trixie sh -ec '
		apt-get update -qq
		DEBIAN_FRONTEND=noninteractive apt-get install -y -qq --no-install-recommends \
			build-essential ca-certificates dkms git linux-headers-amd64 make >/dev/null
		cd /src
		git config --global --add safe.directory /src
		./scripts/create-release-artifacts.sh /out >/dev/null
		./scripts/build-packaged-dkms.sh /out
		tar -tzf /out/*-modules.tar.gz >/dev/null
		test "$(find /out/modules -maxdepth 1 -type f -name "*.ko*" | wc -l)" -eq 5
	'

echo "release_ci=pass platform=$platform"
