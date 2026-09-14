#!/usr/bin/env bash
#
# Assembles changelog.d/ fragments into a release section of CHANGELOG.md.
#
#   tools/assemble-changelog.sh --lint          validate the fragment names
#   tools/assemble-changelog.sh --preview       print what the next release reads
#   tools/assemble-changelog.sh 0.3.0 [DATE]    write it, then delete the fragments
#
set -euo pipefail
shopt -s nullglob

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FRAGMENTS="$ROOT/changelog.d"
CHANGELOG="$ROOT/CHANGELOG.md"
REPO_URL="https://github.com/pepito2t/fight-island"

# Keep a Changelog's own order, which is not alphabetical and is not the order things happen in.
SECTIONS=(added changed deprecated removed fixed security)

usage() {
	sed -n '3,7p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
	exit "${1:-1}"
}

is_section() {
	local candidate="$1" section
	for section in "${SECTIONS[@]}"; do
		[ "$section" = "$candidate" ] && return 0
	done
	return 1
}

# A fragment that no assembler can place is worse than no fragment: it is a written entry that
# disappears at release with nobody looking for it. This is the check CI runs.
lint() {
	local failed=0 path name section
	for path in "$FRAGMENTS"/*; do
		name="$(basename "$path")"
		[ "$name" = "README.md" ] && continue
		if [ -d "$path" ]; then
			echo "changelog.d/$name: directories are not fragments"
			failed=1
			continue
		fi
		if ! printf '%s' "$name" | grep -qE '^[a-z0-9]+(-[a-z0-9]+)+\.md$'; then
			echo "changelog.d/$name: name must be <section>-<slug>.md, lowercase and hyphenated"
			failed=1
			continue
		fi
		section="${name%%-*}"
		if ! is_section "$section"; then
			echo "changelog.d/$name: '$section' is not one of: ${SECTIONS[*]}"
			failed=1
			continue
		fi
		if [ ! -s "$path" ]; then
			echo "changelog.d/$name: empty"
			failed=1
			continue
		fi
		if ! head -n 1 "$path" | grep -q '^- '; then
			echo "changelog.d/$name: must start with a bullet, '- **Something.** ...'"
			failed=1
		fi
	done
	return "$failed"
}

# The fragments of one section, in filename order, under their Keep a Changelog heading.
render() {
	local section files path heading
	for section in "${SECTIONS[@]}"; do
		files=("$FRAGMENTS/$section"-*.md)
		[ "${#files[@]}" -eq 0 ] && continue
		heading="$(printf '%s' "${section:0:1}" | tr '[:lower:]' '[:upper:]')${section:1}"
		printf '### %s\n\n' "$heading"
		for path in "${files[@]}"; do
			cat "$path"
		done
		printf '\n'
	done
}

previous_version() {
	grep -m 1 -oE '^## \[[0-9]+\.[0-9]+\.[0-9]+\]' "$CHANGELOG" | tr -d '#[] ' || true
}

write_release() {
	local version="$1" date="$2" previous section_file link
	section_file="$(mktemp)"
	trap 'rm -f "$section_file"' RETURN

	{
		printf '## [%s] - %s\n\n' "$version" "$date"
		render
	} > "$section_file"

	awk -v section="$section_file" '
		!inserted && /^## \[/ {
			while ((getline line < section) > 0) print line
			inserted = 1
		}
		{ print }
		END { if (!inserted) while ((getline line < section) > 0) print line }
	' "$CHANGELOG" > "$CHANGELOG.tmp"

	previous="$(previous_version)"
	if [ -n "$previous" ]; then
		link="[$version]: $REPO_URL/compare/v$previous...v$version"
		awk -v link="$link" -v previous="[$previous]:" '
			!inserted && index($0, previous) == 1 { print link; inserted = 1 }
			{ print }
			END { if (!inserted) print link }
		' "$CHANGELOG.tmp" > "$CHANGELOG.tmp2"
		mv "$CHANGELOG.tmp2" "$CHANGELOG.tmp"
	else
		printf '[%s]: %s/releases/tag/v%s\n' "$version" "$REPO_URL" "$version" >> "$CHANGELOG.tmp"
	fi

	mv "$CHANGELOG.tmp" "$CHANGELOG"
	for section in "${SECTIONS[@]}"; do
		rm -f "$FRAGMENTS/$section"-*.md
	done
}

case "${1:---help}" in
	--help | -h)
		usage 0
		;;
	--lint)
		lint
		echo "changelog.d: every fragment can be placed."
		;;
	--preview)
		lint >&2
		render
		;;
	-*)
		usage
		;;
	*)
		version="$1"
		printf '%s' "$version" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+$' ||
			{ echo "Not a version: $version" >&2; exit 1; }
		lint >&2
		write_release "$version" "${2:-$(date -u +%F)}"
		echo "CHANGELOG.md now opens on $version. The fragments are gone; commit the deletion."
		;;
esac
