#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
if [ ! -x node_modules/.bin/openspec ]; then
    printf '%s\n' 'Run make setup to install the pinned local OpenSpec CLI.' >&2
    exit 1
fi
OPENSPEC_TELEMETRY=0
export OPENSPEC_TELEMETRY
exec ./node_modules/.bin/openspec "$@"
