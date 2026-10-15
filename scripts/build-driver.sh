#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
./scripts/swift.sh build -c release --product VietMacDriver
vietmac_bin_dir=$(./scripts/swift.sh build -c release --show-bin-path)
vietmac_bundle=.artifacts/VietMacDriver.app
mkdir -p "$vietmac_bundle/Contents/MacOS"
cp "$vietmac_bin_dir/VietMacDriver" "$vietmac_bundle/Contents/MacOS/VietMacDriver"
cp Apps/VietMacDriver/Info.plist "$vietmac_bundle/Contents/Info.plist"
plutil -lint "$vietmac_bundle/Contents/Info.plist"
codesign --force --sign "${VIETMAC_SIGNING_IDENTITY:--}" "$vietmac_bundle"
codesign --verify --strict "$vietmac_bundle"
printf '%s\n' "Built and locally signed $vietmac_bundle (test-only key driver; not launched or installed)."
