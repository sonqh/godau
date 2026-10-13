# Bootstrap verification on 2026 10 13

This report retains the original SonKey names and commands as historical evidence.
The project is now named VietMac; current commands and module names are in the README.

The initial SonKey scaffold passed local source/model checks and builds.
Native Vietnamese typing, application compatibility, and callback performance remain unverified.
The prepared M0 change has 11 implementation tasks with zero completed tasks.

## Environment

- macOS 27.0.1, build 26A434, arm64, 14 logical CPUs.
- Apple Swift 6.4.0 from Command Line Tools.
- Swift language mode 6 and package deployment target macOS 13.
- Node.js 26.10.0, npm 11.19.1, pinned OpenSpec 1.14.1.
- Initial working tree without a Git commit or remote.

The deployment target is not evidence of compatibility on macOS 13 or Intel.
The installed Swift Testing framework reports a macOS 14 target. Tests ran on the current macOS 27 host.

## Executed checks

| Command or check | Result | Evidence scope |
| --- | --- | --- |
| `make check` | Pass | Four OpenSpec items, five Python ledger tests, four Swift model tests, and six replay fixtures |
| `make test-sanitize` | Pass | Four Swift model tests with AddressSanitizer and no reported invalid memory access |
| `make app` | Pass | Release shell compiled and `.artifacts/SonKey.app` assembled |
| `plutil -lint` on the bundle plist | Pass | Bundle metadata syntax |
| `otool -L` on the shell executable | Pass inspection | System framework and Swift runtime dependencies, with no development-tool library dependency |
| Release `sonkey-bench` | Pass | Planner-only synthetic microbenchmark |
| Debug `sonkey-bench` | Expected exit 2 | Refused Debug timing evidence |
| OpenSpec apply instructions | Ready, 0 of 11 tasks complete | Planning exists. Native implementation remains pending. |

The Swift wrapper required an explicit load of the bundled TestingMacros plugin under the current CLT layout.
Initial XCTest and default macro discovery attempts failed before that configuration worked.
The wrapper uses a process-local toolchain selection and does not change Xcode selection or accept a license.
Linker warnings included missing optional developer search paths and the test framework's newer deployment target.
The completed checks and shell build exited successfully despite those warnings.

Temporary command output is under `.artifacts`, which is ignored by Git.
The tracked report and selected JSON baseline preserve the useful evidence for the next agent.

## Planner performance baseline

Source: [release planner baseline](../../benchmarks/baselines/2026-10-13-planner-arm64.json).
Command: `./scripts/swift.sh run -c release sonkey-bench`.
The workload cycles through small edits and a 64-character word after 1,000 warmup iterations.
It records 10,000 samples and consumes results with a checksum.

| Statistic | Nanoseconds | Microseconds |
| --- | ---: | ---: |
| Median | 1792 | 1.792 |
| p95 | 4459 | 4.459 |
| p99 | 5000 | 5.000 |
| Maximum | 40375 | 40.375 |

These local measurements include timer overhead and are not a throughput or allocation benchmark.
They do not establish complete engine, callback, or visible native input latency.
No before/after engine optimization comparison exists yet.

## Pending native evidence

The shell was not launched or installed. Permissions were not requested or changed.
No event tap or full Telex reducer exists in this scaffold.
The no-underline requirement, caret behavior, browser suggestions, and undo behavior still need native verification.
Hosted CI, notarization, and older macOS/Intel verification did not run.

Next action: implement `macos-transport-spike` through the prepared OpenSpec tasks.
Keep its native acceptance tasks pending until results exist for every required app and field family.
