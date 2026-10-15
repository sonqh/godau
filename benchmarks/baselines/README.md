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
