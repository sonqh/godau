# Complete input performance measurement

## ADDED Requirements

### Requirement: Complete reducer measurement
The Release benchmark SHALL offer a complete-composition-reducer scope that includes semantic transition and NFC rendering. It SHALL retain the separate replacement-planner-only scope, reject Debug timing, and consume outputs so measured work is not discarded.

#### Scenario: Measure reducer work
- **WHEN** the complete reducer scope runs in Release
- **THEN** its report declares `complete-composition-reducer`, at least 1,000 warmup events and 10,000 measured events, workload identity, sample count, median, p95, p99, maximum, compiler, OS, and architecture
- **AND** the measurement excludes planner computation, event preparation/posting, and client display latency

#### Scenario: Include boundary and edit workloads
- **WHEN** the reducer workload is constructed
- **THEN** it includes ordinary input, shape/tone changes, mixed case, Backspace, escape, invalidation, and exact-limit/overflow transitions
- **AND** it uses synthetic fixtures rather than recorded user keystrokes

#### Scenario: Keep the existing planner baseline meaningful
- **WHEN** the default planner benchmark is run after the reducer benchmark is added
- **THEN** it still declares `replacement-planner-only`
- **AND** any before/after planner claim compares the same Release workload and environment

### Requirement: Callback own-work evidence
Callback measurements SHALL include input policy, normalization, reduction, planning, and event preparation/posting as callback own-work. Collection SHALL be bounded and export SHALL occur outside the callback without typed-content records.

#### Scenario: Export callback timings
- **WHEN** a Release native session exports callback measurements
- **THEN** the report identifies `callback-own-work`, included operations, workload, sample count, percentiles, maximum, environment, and collection method
- **AND** the key path does not write evidence to disk, update the ledger, present UI, or perform network requests
- **AND** samples contain no typed word or document text

### Requirement: MVP own-work latency budgets
Personal MVP acceptance SHALL require complete-reducer p99 below 1 ms and callback-own-work p99 below 2 ms in the declared synthetic Release workload on the native acceptance machine. Planner measurements SHALL not satisfy either budget.

#### Scenario: Evaluate the measured budgets
- **WHEN** the MVP performance gate is evaluated
- **THEN** separate reducer and callback reports meet their respective budgets without sanitizers or active profilers
- **AND** missing or over-budget results leave performance acceptance pending with the measured limitation documented

### Requirement: Native visible-latency scope
Native visible-latency evidence SHALL identify the observation method, its timing resolution, tested field, workload, and environment. A post duration or callback duration SHALL not be reported as physical-key-to-visible-text latency.

#### Scenario: Observe client display behavior
- **WHEN** a native latency result is reported
- **THEN** it distinguishes callback work, event delivery, and client display observation
- **AND** measurement limits or unavailable timings are explicit rather than inferred from planner or reducer p99
