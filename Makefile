.PHONY: setup check test test-sanitize replay bench bench-engine app app-debug snapshots driver specs ledger

setup:
	npm ci --ignore-scripts --no-audit --no-fund

check: specs ledger test replay

specs:
	npm run spec:check

ledger:
	python3 scripts/ledger.py validate
	python3 -m unittest discover -s scripts/tests -p 'test_*.py'

test:
	./scripts/swift.sh test --disable-xctest

test-sanitize:
	ASAN_OPTIONS=detect_leaks=0 ./scripts/swift.sh test --disable-xctest --sanitize address

replay:
	./scripts/swift.sh run vietmac-replay Fixtures/replacement-plans.json
	./scripts/swift.sh run vietmac-replay Fixtures/telex-composition.json

bench:
	./scripts/swift.sh run -c release vietmac-bench

bench-engine:
	./scripts/swift.sh run -c release vietmac-bench --engine

app:
	./scripts/build-app.sh

app-debug:
	./scripts/build-app.sh debug

# Renders every setup step, Help page, Settings tab, and the menu text for every reason (Debug only).
snapshots: app-debug
	rm -rf .artifacts/ux-snapshots
	".artifacts/GoDau Debug.app/Contents/MacOS/VietMac" --snapshot-dir "$(CURDIR)/.artifacts/ux-snapshots"
	defaults delete vietmac.snapshots >/dev/null 2>&1 || true

driver:
	./scripts/build-driver.sh
