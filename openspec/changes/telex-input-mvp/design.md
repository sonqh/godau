# Telex input MVP design

## Context

Verified at review commit `c714a6b69d772ff86ac137843ab6f5c43b9bfa15`: the package contains semantic contracts, a bounded suffix planner, permission preflight checks, and a menu shell.
There is no Telex reducer or native event transport.
The architecture review passed existing checks and 28,052 additional planner fixtures; those results establish neither language rules nor native compatibility.
See [proposal.md](proposal.md) for the outcome and exclusions.

Son selected `hòa`, `khỏe`, and `thúy` on 2026-10-13.
Other detailed escape and editing scenarios are proposed product behavior, not claims about a running implementation.
The `macos-transport-spike` gate must pass before this implementation begins.

## Goals / Non-Goals

**Goals:** one reusable semantic reducer, one renderer for every output path, state that matches the owned visible suffix, and separate evidence for language, adapter, native fields, and performance.

**Non-Goals:** a second transport system, a legacy packed-state port, raw-history restoration, language prediction, synchronous document reads on every key, or extra services/packages.
The proposal lists excluded product features.

## Decisions

### 1. Keep one package and the existing dependency direction

```mermaid
flowchart LR
    OS[Physical keys and lifecycle] --> Platform[VietMacPlatform policy and context]
    Platform --> Core[VietMacCore reducer and NFC renderer]
    Core --> Planner[Existing ReplacementPlan]
    Planner --> Transport[M0 prepared transport]
    Transport --> Field[Accepted native field]
    Transport --> Platform
    App[App menu and settings] --> Platform
    Replay[Semantic replay and tests] --> Core
    Bench[Scoped Release benchmarks] --> Core
```

`VietMacCore` owns language values and transitions only.
`VietMacPlatform` owns normalization, context generation, event pairing, support policy, prepared transport, and lifecycle on one run loop.
`Apps/VietMac` presents settings and status; configuration reaches the owning loop as an immutable snapshot.
The return edge is the generated-event marker bypass, not another reducer pass.

Extend these existing targets rather than creating a package per component.
A small platform test target is justified for synthetic transport/context traces without permission-dependent key interception.
Replay and benchmarks remain development executables with no dependency entering the app.

### 2. Use typed visible-letter state instead of replaying raw keys

The reducer stores bounded logical letters with base, case, and shape; one optional word-level tone; context generation; and tracking/literal-until-boundary status.
A shape operation can retain a small semantic escape marker so its repetition restores the affected shape while preserving the tone.
The marker is invalidated with the word and is not an unbounded raw-key history.

Backspace removes a visible letter and recomputes the tone target.
It never pops a trailing tone key from a raw stack or imports a previous committed word.
This avoids divergence between visible text and a modifier history after editing.
Re-composition across boundaries would require a different ownership/history contract and remains excluded.

Validate `.asciiLetter(UInt8)` before applying letter rules.
The platform derives case from actual event text, not `Shift OR Caps Lock`; keycodes remain responsible for shortcuts/navigation only.
Unexpected semantic values invalidate state rather than entering an unchecked table index.

The reducer returns next state and an explicit intent containing complete previous/desired text and context.
Pass-through letters can update the predicted suffix; transformed or escaped keys are already included in desired text.
The adapter never appends an implicit restore key.
This keeps language behavior identical across transport profiles.

### 3. Make tone placement a case-independent semantic rule

Match rules on normalized base letters while preserving case for rendering.
Use explicit vowel-pattern data and the following precedence for supported nuclei:

1. Exclude `u` from an initial `qu` only when another vowel follows; exclude `i` from initial `gi` only when another vowel follows.
2. Prefer `ê` or `ơ` when present; for `ươ`, the tone belongs on `ơ`. Other single shaped-vowel nuclei retain that shaped target.
3. A one-vowel nucleus targets that vowel. Supported three-vowel nuclei target the middle vowel unless the shaped-vowel rule decides it.
4. Open unshaped `oa`, `oe`, and `uy` target their first vowel under Son's selected convention; a following valid final consonant moves the target to the second vowel.
5. Other supported two-vowel patterns use their explicit table entry, including final-glide patterns such as `ai`, `ao`, `au`, and `ay`.

Populate these patterns and their intermediate unshaped forms together so a late shape key and a tone entered before the final consonant remain deterministic.
The fixture families are `qu`, `gi`, `iê`, `yê`, `uô`, `ươ`, `oa`, `oe`, `uy`, and supported two/three-vowel forms.
The `thuowr` → `thuở` exception matches normalized letters/context and must produce the same rule result in uppercase and mixed case.
Do not inherit an entire OpenKey vowel table as a correctness oracle.

A supported modifier replaces the relevant shape/tone; repeating that accepted modifier restores it and appends the actual repeated character.
Escape enters literal-until-boundary state, preserving the remaining tone when a shape is removed.
Leading `w` also enters literal-until-boundary state; brackets are literal boundaries.
An ineligible `w`/`z` cannot disappear from the predicted word and later cause a tone to delete the wrong visible character.

One NFC renderer handles normal shapes, tone changes, escapes, and Backspace.
Directly writing a base character in a special restore branch is rejected because it can discard tone or case.
Structural eligibility does not prove that a word is Vietnamese; explicit English mode resolves that product ambiguity.

### 4. Reuse M0 preparation and commit state conservatively

Reduction computes a candidate transition without making it the accepted adapter state.
The adapter computes the existing replacement plan, prepares every event, rechecks context/support/capabilities, and posts in order on its owning run loop.
Only a successfully handled transition advances predicted composition; preparation failure clears state and preserves the physical key.
The original transformed key and its matching key-up follow the M0 consume policy.

Posting is not document acknowledgement.
A detected partial send, external edit, or uncertain focus invalidates state and pauses transformation without guessed rollback.
Profiles can differ in transport only after a native reproduction justifies them; they cannot redefine Telex.
Field identity and selected suggestions must be established in each accepted profile.
No cached PID or context token is treated as proof of document text.

Clear all state on observed navigation, selection, click/drag, edit shortcuts, app/field changes, input-source changes, mode changes, sleep/wake, and tap loss.
When a reset leaves word ownership uncertain, stay literal until a boundary or a positively established new-word start.
Do not adopt preceding document text.
Overflow always stays literal until a boundary, even if later Backspace shortens the visible word.
Keep the logical limit at 64 and encoded generated text within the planner's allowance.

### 5. Keep controls explicit and support policy conservative

Store desired Vietnamese/English mode separately from current availability.
Active transformation requires the accepted app/field profile, ABC or U.S. input, current capabilities, and no secure/uncertain context.
The app shows a concrete pause reason when any gate fails.
User exclusions override the tested scope; no per-app language memory is introduced.

Use the menu toggle immediately; the optional shortcut is initially unset and requires a non-modifier key plus Command, Control, or Option.
Ignore shortcut autorepeat until the corresponding physical release.
Do not reserve a guessed default or interpret modifier-release gestures.
A native test can configure a chord and record it after checking the required apps for conflicts.

Preferences use VietMac's own domain and are written outside the callback.
First launch is English mode; subsequent launches restore desired preferences without restoring composition.
Use macOS's main-app login registration for the opt-in setting, and present actual registration state.
Prevent a second transforming instance in the same user session; do not coordinate composition through shared process state.
Personal build/signing location remains stable for permission evidence.
The agent must not grant permissions, accept licenses, change global developer settings, install, or register startup automatically.

### 6. Verify language and native behavior with different evidence

Extend `vietmac-replay` with semantic-event fixtures while preserving its existing planner fixtures.
Each semantic fixture includes mode/configuration, context events, expected action, and exact text after every key.
Use explicit expected strings; randomized checks use a separate simulated document to verify ownership, pass-through, and NFC/bounds invariants.
They cannot establish linguistic correctness by agreeing with the production renderer.

Translate relevant OpenKey failure families to the selected MVP behavior: standalone `w`/brackets, case-independent `thuở`, preserved tone during shape escape, and no raw-history recovery after boundary deletion.
VNI/Windows failures do not become VietMac requirements.
Sanitizers run separately when indexes, bounds, or ownership change.

Create native evidence during implementation, with 17 field groups and the scenarios in `telex-mvp-acceptance`.
Each group tests a pre-populated synthetic prefix/suffix, `tieengs Vieetj`, edits, case, escapes, suggestion selection, focus transitions, and lifecycle where applicable.
Record exact text and caret/selection alongside formatting, clipboard, underline, and invisible-character checks.
Undo grouping can vary; require a correct controlled undo/redo round trip and report its actual steps.
Terminal transformation stays unsupported and must pass ordinary-input preservation tests.

Do not reduce the matrix when an app is unavailable.
Do not count M0's two rules as full-engine evidence.
Existing specifications under `openspec/specs` remain the delivered baseline until implementation and acceptance support promotion.

### 7. Extend benchmark scope without changing existing claims

Keep `make bench` as the existing planner benchmark.
Add an explicit reducer scope to the current benchmark executable and document a `make bench-engine` entry point during implementation.
The reducer scope includes transition plus rendering, with at least 1,000 warmup events and 10,000 measured synthetic events; it excludes planning and transport.

Reuse M0's bounded timing storage for callback own-work and export outside the callback.
Callback scope includes policy, normalization, reduction, planner, event preparation, and synchronous posting; it excludes client display acknowledgement.
The proposed MVP gates are reducer p99 < 1 ms and callback own-work p99 < 2 ms on the acceptance machine.
Measure Release without sanitizers/profilers and save workload, compiler, environment, sample count, percentiles, and maximum.
Keep native visible-latency method/resolution and allocation evidence distinct; do not infer them from a fast planner.

## Risks / Trade-offs

- Unobserved document changes can invalidate the predicted suffix → use tested profiles, conservative resets, targeted native reproductions, and an unresolved-field completion block.
- Conservative literal fallback can reduce transformation availability → show the reason and resume only at a safe boundary/context; preserve text rather than guessing ownership.
- Telex also matches English identifiers → expose explicit mode controls; no automatic language claim.
- Vowel tables can encode a case-dependent exception → typed normalized rules and lower/upper/mixed-case fixture families.
- Escape and Backspace can diverge from raw input history → own visible logical state and keep committed-word restoration excluded.
- Event-based edits can create different undo grouping → record the grouping and require round-trip preservation, without a single-step promise.
- Local Release measurements do not establish all hardware/OS support → state the tested environment and retain older macOS/Intel as unverified unless tested.

## Migration Plan

1. Complete and review M0 native evidence before beginning engine implementation.
2. Land M1 reducer, semantic replay, fixtures, and scoped benchmark with focused model/sanitizer checks and usage documentation.
3. Land M2 integration, tested-context gating, controls, and synthetic adapter checks; remove prototype language rules.
4. Complete M3 stable personal build, native field matrix, lifecycle/startup tests, and performance evidence before claiming MVP completion.

These stages are outcomes inside one change, not a mandatory PR per component.
Review or merge in that order when separate PRs are useful; merging requires Son's authorization.
Until acceptance passes, retain the scaffold/native development status in user-facing documentation.
Disable transformation for rollback; do not repair user documents or replace installed input apps automatically.
Archive/sync only after completion criteria pass through the corresponding workflow.

## References

- [Official UniKey Telex manual](https://www.unikey.org/support/ukmanual.html): reference for modifier keys, tone replacement/removal, and repeated-key escape; not an oracle for every VietMac rule.
- [Official UniKey Simple Telex release](https://www.unikey.org/version_4_6_2.html): reference for preserving leading `w` and literal brackets.
- [VietMac provenance](../../../docs/provenance.md): exact OpenKey research commit and selected earlier regression evidence. No legacy source/table is copied by this planning change.
