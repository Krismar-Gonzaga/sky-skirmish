#!/usr/bin/env bash
# Builds the Android APK, after proving the exported game data is complete.
#   tools/export_android.sh debug     builds build/sky-skirmish-debug.apk
#   tools/export_android.sh release   builds build/sky-skirmish.apk
# Release builds need these set first (see docs/BUILD.md):
#   GODOT_ANDROID_KEYSTORE_RELEASE_PATH
#   GODOT_ANDROID_KEYSTORE_RELEASE_USER
#   GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT" || exit 1
. tools/find_godot.sh

MODE="${1:-debug}"
mkdir -p build

case "$MODE" in
	debug)
		EXPORT_FLAG="--export-debug"
		OUTPUT="build/sky-skirmish-debug.apk"
		;;
	release)
		EXPORT_FLAG="--export-release"
		OUTPUT="build/sky-skirmish.apk"
		for variable in GODOT_ANDROID_KEYSTORE_RELEASE_PATH GODOT_ANDROID_KEYSTORE_RELEASE_USER GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD; do
			if [ -z "${!variable:-}" ]; then
				echo "$variable is not set. See docs/BUILD.md." >&2
				exit 1
			fi
		done
		;;
	*)
		echo "Usage: tools/export_android.sh debug|release" >&2
		exit 1
		;;
esac

"$GODOT" --headless --path . --import >/dev/null 2>&1

echo "== Checking the exported game data =="
PACK="build/export_check.pck"
"$GODOT" --headless --path . --export-pack "Android" "$PACK" >/dev/null 2>&1
# Run from another folder, so nothing can be read from the project by accident.
check_output="$(cd build && "$GODOT" --headless --main-pack export_check.pck -s "$ROOT/tools/check_export.gd" 2>&1)"
rm -f "$PACK"
if ! echo "$check_output" | grep -q "EXPORT_CHECK PASS" \
		|| echo "$check_output" | grep -E "^(ERROR|SCRIPT ERROR)" >/dev/null; then
	echo "$check_output" | grep -E "EXPORT_CHECK|^(ERROR|SCRIPT ERROR)" | sort -u | head -n 30
	echo "The exported game is incomplete; APK not built." >&2
	exit 1
fi
echo "complete"

echo "== Building $OUTPUT =="
if ! "$GODOT" --headless --path . "$EXPORT_FLAG" "Android" "$OUTPUT" 2>&1 | grep -E "^(ERROR|SCRIPT ERROR)|Signed"; then
	echo "Export failed." >&2
	exit 1
fi
if [ ! -f "$OUTPUT" ]; then
	echo "Export did not produce $OUTPUT." >&2
	exit 1
fi
echo "Built $OUTPUT"
