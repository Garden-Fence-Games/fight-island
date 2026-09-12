#!/usr/bin/env bash
# One headless check, with a wall clock and an eye on what Godot actually said.
#
# A GDScript file that fails to parse does not fail the check that uses it. The scene loads without
# the script, `_ready` never runs, nothing ever calls `quit()`, and the process sits in its idle
# loop until something else kills it. The same happens when a runtime error aborts `_run()` halfway
# through, or when an `await` never resolves. All three read as a slow machine rather than as a
# broken check — which is exactly what they cost the first time.
#
# So: a check that has not finished in time fails, and a check that never said it passed fails too.
#
#   tools/run-check.sh res://tools/verify_waves.tscn      # a scene
#   tools/run-check.sh tools/verify_project_config.gd     # a script
#
# GODOT, PROJECT and CHECK_SECONDS override the binary, the project root and the wall clock.
set -uo pipefail

GODOT="${GODOT:-godot}"
PROJECT="${PROJECT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
CHECK_SECONDS="${CHECK_SECONDS:-300}"

target="${1:-}"
if [ -z "$target" ]; then
	echo "usage: tools/run-check.sh <res://tools/verify_x.tscn | tools/verify_x.gd>" >&2
	exit 2
fi

log="$(mktemp)"
trap 'rm -f "$log"' EXIT

case "$target" in
	*.gd) "$GODOT" --headless --path "$PROJECT" --script "$target" >"$log" 2>&1 & ;;
	*) "$GODOT" --headless --path "$PROJECT" "$target" >"$log" 2>&1 & ;;
esac
godot=$!

# The log is watched rather than read at the end, because the process this is protecting against is
# the one that never exits: a script that did not compile says so in the first second and would
# otherwise sit out the whole wall clock before anyone was told why.
broken() {
	grep -qE "Parse Error|Compile Error|Failed to load script" "$log"
}

waited=0
while kill -0 "$godot" 2>/dev/null; do
	if broken; then
		kill -9 "$godot" 2>/dev/null
		wait "$godot" 2>/dev/null
		cat "$log"
		echo "::error::$target did not compile."
		echo "check FAILED — $target did not compile. See the parse errors above."
		exit 1
	fi
	if [ "$waited" -ge "$CHECK_SECONDS" ]; then
		kill -9 "$godot" 2>/dev/null
		wait "$godot" 2>/dev/null
		cat "$log"
		echo "::error::$target ran for ${CHECK_SECONDS}s without finishing."
		echo "check FAILED — $target never finished. A check that cannot end is a check that"
		echo "  never loaded its script, hit a runtime error before it could report, or is waiting"
		echo "  on something that is not coming. The log above says which."
		exit 1
	fi
	sleep 1
	waited=$((waited + 1))
done
wait "$godot"
status=$?

cat "$log"

# Godot exits 0 for a scene whose script never loaded, so the log is the only witness.
if broken; then
	echo "::error::$target did not compile."
	echo "check FAILED — $target did not compile. See the parse errors above."
	exit 1
fi

if [ "$status" -ne 0 ]; then
	echo "check FAILED — $target exited $status."
	exit "$status"
fi

# Every check ends by printing "<name> OK — <what it proved>". One that exits cleanly without
# saying so has not passed; it has stopped.
if ! grep -q "OK —" "$log"; then
	echo "::error::$target exited 0 without reporting a pass."
	echo "check FAILED — $target exited cleanly but never said it passed."
	exit 1
fi
