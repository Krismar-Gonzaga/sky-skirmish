#!/usr/bin/env bash
# Runs every automated check. Windows: run from Git Bash, not WSL.
# Exits non-zero if a test fails or Godot reports an error or warning.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT" || exit 1
. tools/find_godot.sh

# Importing first builds the class cache that GUT needs on a clean checkout.
echo "== Import =="
"$GODOT" --headless --path . --import >/dev/null 2>&1

echo "== Parse check =="
parse_output="$("$GODOT" --headless --path . --quit 2>&1)"
echo "$parse_output"
if echo "$parse_output" | grep -E "^(ERROR|WARNING|SCRIPT ERROR)" >/dev/null; then
	echo "Parse check failed: fix the errors and warnings above." >&2
	exit 1
fi

echo "== GDScript warnings =="
# The timeout guards against the debugger prompt looping after a parse error.
lint_output="$(timeout 60 "$GODOT" --headless --path . -d -s "$ROOT/tools/check_warnings.gd" </dev/null 2>&1)"
lint_status=$?
if [ "$lint_status" -ne 0 ] || echo "$lint_output" | grep -E "^(ERROR|WARNING|SCRIPT ERROR|Debugger Break)" >/dev/null; then
	echo "$lint_output" | grep -E "^(WARNING|SCRIPT ERROR|Debugger Break)" | sort -u | head -n 40
	echo "Warning check failed: fix the items above." >&2
	exit 1
fi
echo "none"

echo "== GUT =="
# Fixed FPS runs simulated time as fast as the CPU allows: long bot soak tests
# then take seconds, and each frame is exactly one physics step.
"$GODOT" --headless --path . --fixed-fps 60 -s addons/gut/gut_cmdln.gd \
	-gdir=res://tests -ginclude_subdirs -gexit
gut_status=$?
if [ "$gut_status" -ne 0 ]; then
	exit "$gut_status"
fi

echo "== Network =="
bash tools/run_net_tests.sh || exit 1

if [ -f server/package.json ]; then
	echo "== Relay tests =="
	(cd server && npm test) || exit 1
fi

echo "All checks passed."
