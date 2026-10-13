# Performance Measurement

## Purpose

Provide reproducible measurements whose scope does not exceed the code exercised by the workload.

## Requirements

### Requirement: Release measurements with a declared scope
The benchmark SHALL reject Debug builds and identify the measured scope in its JSON output.

#### Scenario: Measure the delivered planner
- **WHEN** the release benchmark runs on the initial scaffold
- **THEN** its report declares `replacement-planner-only`
- **AND** it reports sample count, warmup, percentiles, maximum, and OS information

#### Scenario: Avoid Debug timing claims
- **WHEN** the benchmark executable runs from a Debug build
- **THEN** it returns a nonzero status with a request to use Release

### Requirement: Bounded synthetic workload
The planner benchmark SHALL include small edits and a maximum-size tracked word without collecting real keystrokes.

#### Scenario: Measure a 64-character suffix change
- **WHEN** the benchmark cycles through its synthetic cases
- **THEN** a 64-character case exercises the tracked-word bound
- **AND** the benchmark consumes planner results rather than discarding them

### Requirement: Claims match the measurement
Performance evidence SHALL distinguish planner timing from reducer, callback, native delivery, and allocation measurements.

#### Scenario: Record a planner baseline
- **WHEN** an agent saves a planner measurement
- **THEN** the evidence reports the workload, build, compiler, environment, and measurement scope
- **AND** it does not claim that complete native input meets a latency target
