#!/usr/bin/env bash
#
# The application icon, drawn from the logo rather than stored twice.
#
#   tools/build-icon.sh            write icon.png
#   tools/build-icon.sh 0.9 out.png   try a different fill, somewhere else
#
# **Not a Godot scene any more.** It was one, and it needed a real rendering context: `--headless`
# cannot rasterise an SVG and silently wrote an icon with no mark on it, while opening the scene in
# the editor ran a `@tool` script that ends by quitting — so the editor closed on whoever tried.
# rsvg and ImageMagick do the same job on the CPU, in a second, from a terminal or from CI.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOGO="$ROOT/assets/logo/fight_island_logo_1.svg"
SIDE=1024
## macOS rounds nothing for you and Windows rounds nothing either, so the corner is drawn. A tenth
## of the side is the radius Apple's own grid uses.
CORNER=102
## The sea at the edge of the menu's backdrop, so the icon and the first screen are the same colour.
GROUND="srgb(14,19,27)"
## How much of the square the mark is allowed, measured on the mark's **own** extent rather than on
## its artboard. The logo sits at about five sixths of its viewBox and off-centre inside it, so a
## figure applied to the file as a whole leaves the mark far smaller than it reads on paper — and
## off to one side. Trimming first is what makes this number mean what it says.
FILL="${1:-0.86}"
OUT="${2:-$ROOT/icon.png}"

for tool in rsvg-convert magick; do
	command -v "$tool" >/dev/null || { echo "$tool is not installed" >&2; exit 1; }
done

mark=$(python3 -c "print(int(round($SIDE * $FILL)))")
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

# Rasterised large and trimmed, rather than trimmed in the SVG: the paths are a 70 kB tangle and
# nothing here should have an opinion about where a path ends.
rsvg-convert -w $((SIDE * 2)) -h $((SIDE * 2)) "$LOGO" -o "$work/mark.png"
magick "$work/mark.png" -trim +repage -resize "${mark}x${mark}" \
	-background none -gravity center -extent "${SIDE}x${SIDE}" "$work/centred.png"
magick -size "${SIDE}x${SIDE}" xc:none \
	-fill "$GROUND" -draw "roundrectangle 0,0 $((SIDE - 1)),$((SIDE - 1)) $CORNER,$CORNER" \
	"$work/centred.png" -gravity center -composite \
	"$OUT"

echo "$(basename "$OUT") is ${SIDE}x${SIDE}, the mark filling ${mark}px of it."
