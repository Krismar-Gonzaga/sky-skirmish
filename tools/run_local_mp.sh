#!/usr/bin/env bash
# Opens two windows on this PC and starts a 1 vs 1 LAN match between them.
# Each window has its own save profile. Close either window to test a forfeit.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT" || exit 1
. tools/find_godot.sh

"$GODOT" --path . --resolution 960x540 --position 0,40 -- --host --profile=host &
sleep 2
"$GODOT" --path . --resolution 960x540 --position 970,40 -- --join=127.0.0.1 --profile=guest &
wait
