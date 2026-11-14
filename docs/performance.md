# Performance design and measurement

Bounded state and explicit event order are the initial performance decisions.
Optimization claims require release measurements against the same workload and environment.

## Input path constraints

- Limit the tracked word to 64 logical characters and bound encoded output.
- Use one run loop for composition and transport ownership.
- Keep network access, disk writes, ledger updates, UI work, and window enumeration outside the callback.
- Avoid per-key Task creation, actor hops, process creation, and blocking sleeps.
- Keep normalization and generated-event construction bounded.
- Cache configuration and app profiles outside the event path.
- Use app-specific transport behavior only with measured compatibility evidence.

A bounded allocation can be acceptable when it is small and measured.
Do not add custom allocators or unsafe storage merely to claim zero allocations.
The planner currently creates small arrays and uses Foundation NFC checks.
Its benchmark establishes the cost of that implementation, not the cost of a complete engine.

## Measurement scopes

| Scope | How to measure | Status |
| --- | --- | --- |
| Replacement planner | `make bench`, release build, synthetic small and 64-character cases | Implemented |
| Complete composition reducer | `make bench-engine`: Telex composer plus replacement plan per semantic event | Release baseline: p99 3.6 µs, 10,000 samples ([JSON](../benchmarks/baselines/2026-11-14-reducer-arm64.json)) |
| Callback own work | Bounded timings around normalization, prototype reduction, planning, preparation, and posting; menu or `SIGUSR1` export | M0 Release baseline: p99 47.5 µs, 1,368 samples ([JSON](../benchmarks/baselines/2026-10-15-callback-own-work-arm64.json)). Telex composer, `telex-timing-workload` (660 keys, 2026-11-14): p99 84 to 101 µs in Chrome, Dia, Safari |
| Native visible input | Required apps and fields with controlled sequences | Pending |
| Memory and allocations | Instruments or scoped allocation measurements on the release host | Pending |

Provisional goals: reducer p99 below 1 ms and callback own-work p99 below 2 ms in the agreed workload.
These are product budgets, not Apple's timeout thresholds or measured results.
Event delivery and visible application latency require separate observation.

## Benchmark evidence

`vietmac-bench` warms the planner, records 10,000 durations, consumes results with a checksum, and emits JSON percentiles.
It refuses a Debug build. Measurements include timer overhead and are a local microbenchmark.
Run without sanitizers or active profilers when collecting comparable baseline timings.
Run sanitizer checks separately for safety.

```sh
make bench
```

Keep a selected baseline under `benchmarks/baselines` with the compiler, machine architecture, OS, workload, and command recorded.
Use `.artifacts` for temporary captures. Promote only useful evidence rather than every local run.
Do not label a planner improvement as an engine or native input improvement.
Large regressions need investigation before adding a hard CI threshold.
Native distribution and hosted CI are later work, not a scaffold dependency.
