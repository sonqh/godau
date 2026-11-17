#!/bin/sh
# Packages the Release app for another Mac: a universal (arm64 + x86_64) bundle in a zip, with its SHA-256.
# Output in .artifacts/dist: GoDau.zip, GoDau.zip.sha256, and install.sh. Signing follows build-app.sh (VIETMAC_SIGNING_IDENTITY, else ad hoc).
# This script does not notarize, upload, or install anything.
set -eu
cd "$(dirname "$0")/.."
VIETMAC_UNIVERSAL=1 ./scripts/build-app.sh release
bundle=.artifacts/GoDau.app
archs=$(lipo -archs "$bundle/Contents/MacOS/VietMac")
case "$archs" in
    *arm64*x86_64*|*x86_64*arm64*) ;;
    *) printf '%s\n' "Expected a universal binary, found: $archs" >&2; exit 1 ;;
esac
version=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$bundle/Contents/Info.plist")
rm -rf .artifacts/dist
mkdir -p .artifacts/dist
# Fixed names, so one download address serves every version.
zip=.artifacts/dist/GoDau.zip
# ditto keeps the signature and extended attributes that a plain zip can drop.
ditto -c -k --keepParent "$bundle" "$zip"
(cd .artifacts/dist && shasum -a 256 GoDau.zip > GoDau.zip.sha256)
# The installer carries the download address. Set VIETMAC_DIST_URL to the folder that will hold these files.
sed "s|__GODAU_BASE_URL__|${VIETMAC_DIST_URL:-__GODAU_BASE_URL__}|" scripts/install.sh > .artifacts/dist/install.sh
chmod +x .artifacts/dist/install.sh
printf '%s\n' "Packaged $zip, version $version ($archs)."
cat "$zip.sha256"
if [ -z "${VIETMAC_DIST_URL:-}" ]; then
    printf '%s\n' "VIETMAC_DIST_URL is not set: install.sh needs GODAU_BASE_URL when it runs."
fi
