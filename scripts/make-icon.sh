#!/bin/sh
# Renders every icon size with scripts/make-icon.swift and writes Apps/VietMac/AppIcon.icns.
set -eu
cd "$(dirname "$0")/.."
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
set_dir="$work/AppIcon.iconset"
mkdir -p "$set_dir"
for size in 16 32 128 256 512; do
    swift scripts/make-icon.swift "$set_dir/icon_${size}x${size}.png" "$size"
    swift scripts/make-icon.swift "$set_dir/icon_${size}x${size}@2x.png" "$((size * 2))"
done
iconutil -c icns "$set_dir" -o Apps/VietMac/AppIcon.icns
printf '%s\n' "Wrote Apps/VietMac/AppIcon.icns."
