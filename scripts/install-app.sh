#!/bin/sh
# Installs the Release build to /Applications/GoDau.app: stops a running copy, replaces it, and opens it.
# Run `make app` first. The bundle ID stays io.github.sonqh.godau, so permissions and preferences carry over
# when the signing identity is unchanged.
set -eu
cd "$(dirname "$0")/.."
source_bundle=.artifacts/GoDau.app
target=/Applications/GoDau.app
[ -d "$source_bundle" ] || { printf '%s\n' "Missing $source_bundle; run make app first." >&2; exit 1; }
codesign --verify --strict "$source_bundle"
if pkill -TERM -f "$target/Contents/MacOS/VietMac"; then
    # Wait up to 5 s for the running copy to exit before replacing its files.
    for _ in 1 2 3 4 5 6 7 8 9 10; do
        pgrep -f "$target/Contents/MacOS/VietMac" >/dev/null || break
        sleep 0.5
    done
fi
rm -rf "$target"
ditto "$source_bundle" "$target"
codesign --verify --strict "$target"
open "$target"
printf '%s\n' "Installed and opened $target."
