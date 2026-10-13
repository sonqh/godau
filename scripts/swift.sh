#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
if [ -n "${SONKEY_SWIFT_BIN:-}" ]; then
    exec "$SONKEY_SWIFT_BIN" "$@"
fi
if [ -x /Library/Developer/CommandLineTools/usr/bin/swift ]; then
    DEVELOPER_DIR=/Library/Developer/CommandLineTools
    SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk
    export DEVELOPER_DIR SDKROOT
    sonkey_testing_plugin=/Library/Developer/CommandLineTools/usr/lib/swift/host/plugins/testing/libTestingMacros.dylib
    if [ "${1:-}" = test ] && [ -f "$sonkey_testing_plugin" ]; then
        # CLT Swift 6.4 places this plugin outside the default plugin search path.
        exec /Library/Developer/CommandLineTools/usr/bin/swift "$@" \
            -Xswiftc -load-plugin-library -Xswiftc "$sonkey_testing_plugin"
    fi
    exec /Library/Developer/CommandLineTools/usr/bin/swift "$@"
fi
exec swift "$@"
