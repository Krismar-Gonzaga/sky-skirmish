#!/usr/bin/env bash
# Real network tests: two Godot processes talking ENet over localhost.
# Runs T6, T9 and T10 from the design, plus joining when nobody is hosting.
# Usage: tools/run_net_tests.sh [-v]    (-v prints each process's whole log)
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT" || exit 1
. tools/find_godot.sh

VERBOSE="${1:-}"
LOGS="$(mktemp -d)"
FAILED=0
PORT=47950
RELAY=""
RELAY_PID=""

probe() {
	"$GODOT" --headless --path . -s res://tests/net/net_probe.gd -- \
		--role="$1" --scenario="$2" --port="$3" --relay="$RELAY" \n		--codefile="$LOGS/$2.code" >"$LOGS/$2_$1.log" 2>&1
}

report() {
	local name="$1"
	grep -h "NET_TEST" "$LOGS/$name"_*.log | sed 's/\x1b\[[0-9;]*m//g'
	# Errors from a process that deliberately killed itself would not be flushed.
	grep -hE "^(ERROR|SCRIPT ERROR|WARNING)" "$LOGS/$name"_*.log | sort -u | head -n 20
	if grep -qE "^(ERROR|SCRIPT ERROR|WARNING)" "$LOGS/$name"_*.log; then
		FAILED=1
	fi
	if [ "$VERBOSE" = "-v" ]; then
		cat "$LOGS/$name"_*.log
	fi
}

# pair NAME HOST_MUST_PASS CLIENT_MUST_PASS
pair() {
	local name="$1" host_must="$2" client_must="$3"
	PORT=$((PORT + 1))
	probe host "$name" "$PORT" &
	local host_pid=$!
	sleep 2
	probe client "$name" "$PORT" &
	local client_pid=$!
	wait "$host_pid"; local host_status=$?
	wait "$client_pid"; local client_status=$?
	echo "== $name: host exit $host_status, client exit $client_status"
	report "$name"
	if [ "$host_must" = yes ] && [ "$host_status" -ne 0 ]; then FAILED=1; fi
	if [ "$client_must" = yes ] && [ "$client_status" -ne 0 ]; then FAILED=1; fi
}

pair t6 yes yes
pair lobby yes yes
pair rematch yes yes
pair t10 yes yes
pair t9_client_drops yes no
pair t9_host_drops no yes
pair t9_no_network no yes

PORT=$((PORT + 1))
probe client no_host "$PORT"
no_host_status=$?
echo "== no_host: client exit $no_host_status"
report no_host
if [ "$no_host_status" -ne 0 ]; then FAILED=1; fi

start_relay() {
	PORT=$((PORT + 1))
	RELAY="ws://127.0.0.1:$PORT"
	(cd server && PORT=$1 exec node relay.js) >"$LOGS/relay.log" 2>&1 &
	RELAY_PID=$!
}

if [ ! -d server/node_modules ]; then
	(cd server && npm ci --no-audit --no-fund) || exit 1
fi

start_relay "$((PORT + 1))"
sleep 1
pair t7 yes yes
pair online_t10 yes yes
pair online_client_drops yes no
pair online_host_drops no yes
pair online_rematch yes yes

PORT=$((PORT + 1))
probe client t8 "$PORT"
t8_status=$?
echo "== t8: client exit $t8_status"
report t8
if [ "$t8_status" -ne 0 ]; then FAILED=1; fi

kill "$RELAY_PID" 2>/dev/null
wait "$RELAY_PID" 2>/dev/null

# The server comes up 5 s after the client starts, like a free host waking.
PORT=$((PORT + 1))
WAKE_PORT=$PORT
RELAY="ws://127.0.0.1:$WAKE_PORT"
probe client waking "$WAKE_PORT" &
waking_pid=$!
sleep 5
(cd server && PORT=$WAKE_PORT exec node relay.js) >"$LOGS/relay2.log" 2>&1 &
RELAY_PID=$!
wait "$waking_pid"
waking_status=$?
echo "== waking: client exit $waking_status"
report waking
if [ "$waking_status" -ne 0 ]; then FAILED=1; fi
kill "$RELAY_PID" 2>/dev/null
wait "$RELAY_PID" 2>/dev/null

rm -rf "$LOGS"
if [ "$FAILED" -ne 0 ]; then
	echo "Network tests FAILED." >&2
	exit 1
fi
echo "Network tests passed."
