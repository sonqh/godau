# Development Workflow

## Purpose

Let Claude, Codex, and Son continue development through one set of specifications, tasks, and evidence records.

## Requirements

### Requirement: Shared agent instructions
Claude and Codex SHALL use the same project instructions and OpenSpec artifacts.
The project SHALL keep the OpenSpec CLI pinned as a local development dependency.

#### Scenario: Resume a prepared change with either agent
- **WHEN** Claude or Codex starts `macos-transport-spike`
- **THEN** the agent reads the same proposal, design, delta specifications, and tasks
- **AND** terminal OpenSpec operations use the local CLI wrapper

### Requirement: Append-only development evidence
The development ledger SHALL append typed decision, verification, and handoff records without rewriting earlier records.
Verification records MUST contain a command and a pass, fail, or not-run result.

#### Scenario: Add verification after model checks
- **WHEN** an agent records a successful model check
- **THEN** the new record identifies its scope, confidence, evidence, and relevant artifacts
- **AND** previous ledger bytes remain unchanged

#### Scenario: Refuse an incomplete ledger
- **WHEN** the existing ledger ends with a partial record
- **THEN** the append command reports an error and preserves existing bytes

### Requirement: Runtime and development separation
The input app and reusable core SHALL have no dependency on the development ledger, Node.js, Python, or OpenSpec.

#### Scenario: Build the app runtime
- **WHEN** Swift builds `VietMacApp`
- **THEN** its application dependency path contains `VietMacPlatform` and `VietMacCore`
- **AND** no development ledger module enters that path

### Requirement: Evidence scope stays explicit
The workflow SHALL separate source/model checks, native behavior, and performance claims.

#### Scenario: Build a scaffold without native testing
- **WHEN** a build or model replay succeeds but no native typing session runs
- **THEN** native acceptance tasks remain pending
- **AND** the completion report identifies native behavior as unverified
