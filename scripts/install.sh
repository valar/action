#!/usr/bin/env bash
# Installs the Valar CLI release VALAR_CLI_VERSION for the runner and puts it
# on PATH. Binaries of releases listed in checksums.txt are verified.
set -euo pipefail

version=${VALAR_CLI_VERSION#v}
case "${RUNNER_OS:-}" in
Linux) os=linux ;;
macOS) os=darwin ;;
*)
	echo "::error::valar/action runs on Linux and macOS runners, not ${RUNNER_OS:-unknown}."
	exit 1
	;;
esac
case "${RUNNER_ARCH:-}" in
X64) arch=amd64 ;;
ARM64) arch=arm64 ;;
ARM) arch=arm ;;
*)
	echo "::error::The Valar CLI has no build for ${RUNNER_ARCH:-unknown} runners."
	exit 1
	;;
esac
asset="valar_${os}_${arch}"
dir="${RUNNER_TOOL_CACHE:-$RUNNER_TEMP}/valar/$version/$arch"

if [ ! -x "$dir/valar" ]; then
	mkdir -p "$dir"
	curl -fsSL --retry 3 -o "$dir/valar.download" \
		"https://github.com/valar/cli/releases/download/v$version/$asset"
	want=$(awk -v name="$version/$asset" '$2 == name { print $1 }' "$GITHUB_ACTION_PATH/scripts/checksums.txt")
	if [ -n "$want" ]; then
		if command -v sha256sum >/dev/null; then
			got=$(sha256sum "$dir/valar.download" | cut -d' ' -f1)
		else
			got=$(shasum -a 256 "$dir/valar.download" | cut -d' ' -f1)
		fi
		if [ "$got" != "$want" ]; then
			rm -f "$dir/valar.download"
			echo "::error::The Valar CLI $version download ($asset) does not match its checksum."
			exit 1
		fi
	else
		echo "::notice::CLI $version is not in this action's checksums; its download is not verified."
	fi
	chmod +x "$dir/valar.download"
	mv "$dir/valar.download" "$dir/valar"
fi
echo "$dir" >>"$GITHUB_PATH"
"$dir/valar" --version
