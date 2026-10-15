# OpenKey failure analysis

This note records why Son's daily OpenKey failures happen and how VietMac avoids or detects them.
It is based on reading OpenKey at commit `89c2fd3` (`Sources/OpenKey/macOS/ModernKey/OpenKey.mm` and `AppDelegate.m`) on 2026-10-15.
"Verified" means read in the code. "Inferred" means the runtime effect follows from the code but was not reproduced with OpenKey.

## Son's reported failures

Son reports three recurring problems with OpenKey: lost text, duplicated text, and tone marks in the wrong Vietnamese form.

| Failure | OpenKey cause | VietMac status |
| --- | --- | --- |
| Lost text | Every Unicode insertion is posted as virtual key 0 (`kVK_ANSI_A`): `CGEventCreateKeyboardEvent(myEventSource, 0, …)` in `OpenKey.mm` lines 254, 290, 300, 311, 327, 348, and 496 (verified). While the physical A key is still down (key rollover), the client drops that keydown after the Backspace has landed (reproduced with VietMac's original M0 build in Chrome) | Fixed. Insertion uses the consumed trigger key. Passed manual and automated rollover runs in Chrome, Dia, and Safari |
| Duplicated text (`aá`) | Backspace removes a selected suggestion or is dropped, then the insertion lands. OpenKey has no field observation. Its workaround inserts invisible U+202F (or U+200C) and one extra Backspace, or uses Shift+Left only for a hard-coded app list (Chrome, Brave, Edge variants). Dia is not listed, and the release Edge ID `com.microsoft.edgemac` is missing (verified) | Selections are observed before sending, so Backspace is not sent into a suggestion (automated in three browsers; real address bars pending). A field mismatch right after a replacement now counts `replacementsUnconfirmed` and pauses instead of continuing |
| Tone placement or form | Configurable placement and code tables, including Unicode compound output in some apps | `telex-input-mvp` fixes one convention (`hòa`, `khỏe`, `thúy`; tone recomputed as the nucleus changes) and NFC precomposed output only. Son's concrete examples are still needed to confirm coverage |

## Context handling

OpenKey resets its word on mouse down or drag (`RequestNewSession`) and on a Space change.
An application switch changes the language only with smart switch enabled and does not reset the word (verified).
It does not read focus, caret, length, or selection, so programmatic focus changes, external edits, and inline completions are invisible to it (inferred effect: wrong Backspace target).
VietMac observes focused-element identity, caret, length, and selection through Accessibility outside the callback and requires a settled observation before any deletion.

## Callback cost

For every transformed key, OpenKey calls `isSpotlightVisible()` twice (`shouldUseRecommendWorkaround` and `shouldUseSelectionReplacement`). Each call enumerates on-screen windows with `CGWindowListCopyWindowInfo` inside the event tap callback (verified). The latency was not measured.
With "turn off Vietnamese in other languages", it reads the input source on every key and releases it only on one branch (verified).
VietMac keeps window enumeration, I/O, and source lookups outside the callback. Its M0 callback own-work p99 is about 50–60 µs (`benchmarks/baselines/2026-10-15-callback-own-work-arm64.json`).

## Out of scope

Microsoft Teams with Apple's Vietnamese input method can duplicate text or stall composition because that input method uses marked text.
VietMac never creates marked text, so that failure class does not apply (inferred). Teams is not a required app and was not tested.
