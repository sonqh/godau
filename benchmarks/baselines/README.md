# Performance baselines

Keep selected, scoped Release measurements here.
Every baseline needs a command, compiler, environment, workload, and interpretation in a linked verification report.

The initial [planner JSON](2026-10-13-planner-arm64.json) belongs to the
[bootstrap verification](../../docs/verification/bootstrap.md).
It measures replacement planning only and does not establish native input latency.

Save temporary runs under `.artifacts`.
Do not replace a previous baseline without retaining its history or recording why the comparison changed.
