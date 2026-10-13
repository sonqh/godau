#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
./scripts/swift.sh build -c release --product SonKeyApp
sonkey_bin_dir=$(./scripts/swift.sh build -c release --show-bin-path)
sonkey_bundle=.artifacts/SonKey.app
mkdir -p "$sonkey_bundle/Contents/MacOS"
cp "$sonkey_bin_dir/SonKeyApp" "$sonkey_bundle/Contents/MacOS/SonKey"
cp Apps/SonKey/Info.plist "$sonkey_bundle/Contents/Info.plist"
plutil -lint "$sonkey_bundle/Contents/Info.plist"
printf '%s\n' "Built $sonkey_bundle (not launched or installed)."
