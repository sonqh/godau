#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
./scripts/swift.sh build -c release --product VietMacApp
vietmac_bin_dir=$(./scripts/swift.sh build -c release --show-bin-path)
vietmac_bundle=.artifacts/VietMac.app
mkdir -p "$vietmac_bundle/Contents/MacOS"
cp "$vietmac_bin_dir/VietMacApp" "$vietmac_bundle/Contents/MacOS/VietMac"
cp Apps/VietMac/Info.plist "$vietmac_bundle/Contents/Info.plist"
plutil -lint "$vietmac_bundle/Contents/Info.plist"
codesign --force --sign "${VIETMAC_SIGNING_IDENTITY:--}" "$vietmac_bundle"
codesign --verify --strict "$vietmac_bundle"
printf '%s\n' "Built and locally signed $vietmac_bundle (not launched or installed)."
