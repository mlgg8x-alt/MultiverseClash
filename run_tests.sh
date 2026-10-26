#!/usr/bin/env bash
# Runs the headless test suite. Fails on test failures and on any engine script error.
# Usage: GODOT=/path/to/godot ./run_tests.sh
set -uo pipefail
GODOT="${GODOT:-godot}"
cd "$(dirname "$0")"
"$GODOT" --headless --path . --import >/dev/null 2>&1 || true
out="$("$GODOT" --headless --path . -s res://tests/run_tests.gd 2>&1)"
status=$?
echo "$out"
if grep -qE "SCRIPT ERROR|Parse Error" <<<"$out"; then
	echo "Engine reported script errors" >&2
	exit 1
fi
exit $status
