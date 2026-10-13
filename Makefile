.PHONY: setup check test test-sanitize replay bench app specs ledger

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
	./scripts/swift.sh run sonkey-replay Fixtures/replacement-plans.json

bench:
	./scripts/swift.sh run -c release sonkey-bench

app:
	./scripts/build-app.sh
