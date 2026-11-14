# Performance baselines

Keep selected, scoped Release measurements here.
Every baseline needs a command, compiler, environment, workload, and interpretation in a linked verification report.

The initial [planner JSON](2026-10-13-planner-arm64.json) belongs to the
[bootstrap verification](../../docs/verification/bootstrap.md).
It measures replacement planning only and does not establish native input latency.

The [callback own-work JSON](2026-10-15-callback-own-work-arm64.json) belongs to the
[M0 transport verification](../../docs/verification/macos-transport-spike.md) (task 2.3).
It measures event-tap callback own-work under a synthetic HID-level workload, not planner cost or visible latency.

Save temporary runs under `.artifacts`.
Do not replace a previous baseline without retaining its history or recording why the comparison changed.

The [reducer JSON](2026-11-14-reducer-arm64.json) comes from `make bench-engine` (Release, CLT Swift, macOS 27.0.1, arm64, 14 logical CPUs).
It measures the Telex composer plus the replacement plan per semantic event over Vietnamese words, escapes, Backspace, and boundaries, as described in [docs/telex-composer.md](../../docs/telex-composer.md).
It is not callback own-work or visible latency.
