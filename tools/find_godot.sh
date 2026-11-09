# Sourced by the other tools. Sets GODOT to the engine binary, or exits.
# On Windows use the *_console.exe build; the normal one prints nothing to a pipe.

if [ -f "$ROOT/tools/local.env" ]; then
	. "$ROOT/tools/local.env"
fi

if [ -z "${GODOT:-}" ]; then
	for candidate in godot godot4; do
		if command -v "$candidate" >/dev/null 2>&1; then
			GODOT="$candidate"
			break
		fi
	done
fi

if [ -z "${GODOT:-}" ]; then
	echo "Godot not found. Copy tools/local.env.example to tools/local.env and set GODOT." >&2
	exit 1
fi
