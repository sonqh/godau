#!/bin/sh
# Usage: build-app.sh [release|debug]
# release (default): .artifacts/VietMac.app, no Debug simulator.
# debug: .artifacts/VietMac Debug.app with bundle ID local.sonquach.vietmac.debug and the status simulator.
set -eu
cd "$(dirname "$0")/.."
vietmac_config=${1:-release}
case "$vietmac_config" in
    release) vietmac_bundle=.artifacts/VietMac.app ;;
    debug) vietmac_bundle=".artifacts/VietMac Debug.app" ;;
    *) printf '%s\n' "Unknown configuration: $vietmac_config" >&2; exit 2 ;;
esac
./scripts/swift.sh build -c "$vietmac_config" --product VietMacApp
vietmac_bin_dir=$(./scripts/swift.sh build -c "$vietmac_config" --show-bin-path)
mkdir -p "$vietmac_bundle/Contents/MacOS" "$vietmac_bundle/Contents/Resources"
cp "$vietmac_bin_dir/VietMacApp" "$vietmac_bundle/Contents/MacOS/VietMac"
cp Apps/VietMac/Info.plist "$vietmac_bundle/Contents/Info.plist"
if [ "$vietmac_config" = debug ]; then
    # A separate identity keeps Debug grants and preferences apart from the Release build.
    plutil -replace CFBundleIdentifier -string local.sonquach.vietmac.debug "$vietmac_bundle/Contents/Info.plist"
    plutil -replace CFBundleDisplayName -string "VietMac Debug" "$vietmac_bundle/Contents/Info.plist"
fi
# The string catalog is read at runtime, so it is copied, not compiled.
cp Sources/VietMacShell/Resources/Localizable.xcstrings "$vietmac_bundle/Contents/Resources/Localizable.xcstrings"
plutil -lint "$vietmac_bundle/Contents/Info.plist"
codesign --force --sign "${VIETMAC_SIGNING_IDENTITY:--}" "$vietmac_bundle"
codesign --verify --strict "$vietmac_bundle"
printf '%s\n' "Built and locally signed $vietmac_bundle (not launched or installed)."
