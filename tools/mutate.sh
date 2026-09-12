#!/usr/bin/env bash
# Breaks the game on purpose, one constant at a time, and reports which breakages no check notices.
#
# A check that cannot fail is worse than no check: it buys confidence nobody earned. Reading for
# that does not work — three of the ones found by this script were written by people who believed
# they were holding exactly the thing they were not. So it is measured instead.
#
# The commonest way a guard goes quiet is that it takes its bound from the thing it is checking:
#     var most := deg_to_rad(Player.TURN_SPEED_DEGREES) * ...
# Ten times the turn rate moves the expectation with it and the check passes on a body that spins
# twice in a frame. The fix is always the same — write the figure out, and assert the constant
# against it first, so moving it deliberately is a one-line edit and moving it by accident fails.
#
# Usage:  tools/mutate.sh [tools/mutations.txt]
# Each line of the table: <file>|<original text>|<replacement>|<check,check,...>
# Blank lines and lines starting with # are ignored.
#
# Needs GODOT on the PATH, like every other tool here. Expect a minute per mutation.
set -uo pipefail

table="${1:-tools/mutations.txt}"
[ -r "$table" ] || { echo "no mutation table at $table"; exit 2; }

backup="$(mktemp)"
survivors=0
applied=0

restore() { [ -n "${target:-}" ] && cp "$backup" "$target"; }
trap restore EXIT

while IFS='|' read -r target from to checks; do
	case "$target" in ''|\#*) continue ;; esac
	if [ ! -r "$target" ]; then
		echo "MISSING  $target"
		survivors=$((survivors + 1))
		continue
	fi
	cp "$target" "$backup"
	if ! python3 - "$target" "$from" "$to" <<-'PY'
		import sys
		from pathlib import Path

		path, original, replacement = sys.argv[1], sys.argv[2], sys.argv[3]
		source = Path(path).read_text()
		if original not in source:
		    sys.exit(1)
		Path(path).write_text(source.replace(original, replacement, 1))
	PY
	then
		echo "STALE    $target :: $from"
		survivors=$((survivors + 1))
		continue
	fi
	applied=$((applied + 1))
	caught=""
	for check in ${checks//,/ }; do
		if ! CHECK_SECONDS="${CHECK_SECONDS:-300}" tools/run-check.sh "tools/$check.tscn" >/dev/null 2>&1
		then
			caught="$check"
			break
		fi
	done
	cp "$backup" "$target"
	if [ -n "$caught" ]; then
		echo "caught   $from -> $to   ($caught)"
	else
		echo "SURVIVED $from -> $to   (nothing noticed)"
		survivors=$((survivors + 1))
	fi
done < "$table"

echo
echo "$applied mutations applied, $survivors survived."
[ "$survivors" -eq 0 ] || exit 1
