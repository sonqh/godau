# Research provenance

SonKey's requirements come from Son's instructions on 2026-10-13:

- Personal macOS-only Vietnamese input app.
- Telex and precomposed Unicode for the MVP.
- No composition underline.
- VS Code, Chrome, Edge, Dia, and Notes as required apps.
- Reusable boundaries, extension paths, a development ledger, and measured performance.

Notes currently means Apple Notes. macOS 13 as the deployment floor and the name SonKey are implementation choices.

The source research baseline is OpenKey commit `89c2fd3bf258562f2349f89b49d81e2f140c3fc3`.
The local research source is the sibling `OpenKey` repository.
Its `docs/vietnamese-input-review.md` and `docs/macos-vietnamese-input-design.md` contain the earlier findings and design export.

Verified old-engine examples include invalid standalone indexes, case-dependent vowel rules,
lost tone on shape restoration, and raw history loss after Backspace.
The old check count was 14 passing cases and 12 failing reproductions across engine and Windows helper scopes.
Those counts describe OpenKey, not SonKey's tests or app compatibility.

This scaffold contains original contracts, a planner, and tooling. It does not import OpenKey production code or vowel tables.
If later changes copy source or tables, record the exact source and retain its notices and stated license.

OpenSpec follows the official CLI package, pinned to 1.14.1 in the lockfile.
The setup command was `openspec init --tools claude,codex --profile core --no-animation` through the local package.
See [OpenSpec CLI](https://github.com/Fission-AI/OpenSpec/blob/main/docs/cli.md) for the official structure and commands.

The Swift tests use [Swift Testing](https://developer.apple.com/documentation/testing), which integrates with Swift Package Manager.
Native behavior still requires the product's application matrix and cannot follow from framework documentation alone.
