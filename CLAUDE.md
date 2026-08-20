# CLAUDE.md

## Project overview

MacDjView is an independent downstream DjVu viewer for macOS, iPad, and iPhone. It contains a pure-Swift DjVu decoder and uses Apple frameworks for UI/platform integration. Upstream mergeability is not a design requirement; optimize for this repository while keeping changes reviewable and security-conscious.

Read first:

- [`docs/product-direction.md`](./docs/product-direction.md) — product/downstream stance and licensing caveat.
- [`docs/roadmap.md`](./docs/roadmap.md) — current implementation status and next platform work.
- [`docs/architecture.md`](./docs/architecture.md) — decoder and embedded-text architecture.

## Quick reference

- Build: `swift build` / `swift build -c release`.
- Run: `swift run MacDjView`.
- Unit tests: `make unit-test` or `./scripts/run-tests.sh`.
- CLI decode/perf: `swift run -c release MacDjView -- --test file.djvu [startPage]`.
- macOS app bundle: `./scripts/make-app-bundle.sh`.
- Platforms: macOS 14+ arm64; iOS/iPadOS 17+.
- Swift tools: 5.10+; CI may use newer Xcode/SDK.
- Runtime dependencies: none outside Apple/system frameworks.

## Current product state

Implemented:

- bounded DjVu image decoder and sandboxed file loading;
- imported `org.djvu.djvu` UTI;
- `TXTa` / `TXTz` hidden-text decoding;
- native SwiftUI document search;
- macOS `Command-F`, `Command-G`, `Shift-Command-G`;
- page navigation/highlighting from DjVu text-zone coordinates.

Planned next:

- Vision OCR fallback;
- modern macOS toolbar refresh;
- Spotlight content importer;
- Quick Look/Finder thumbnail extensions;
- Instruments-driven rendering optimization.

## Engineering rules

- Treat DjVu input as untrusted; preserve/extend `DecodeLimits` and checked arithmetic.
- Keep deterministic decoder/text parsing independent from platform features such as Vision, Spotlight, and Quick Look.
- Prefer Apple frameworks/native behavior before custom platform code.
- Do not add raw Metal unless profiling demonstrates a real bottleneck that higher-level system acceleration does not solve.
- Keep decoder/security, UI, system integrations, and rendering changes in focused PRs.
- Prefer one meaningful commit per small PR and rebase merges when practical.
- Do not add a blanket project license until inherited-code licensing/provenance is resolved.

## Documentation

- [`docs/code-best-practices.md`](./docs/code-best-practices.md)
- [`docs/key-files.md`](./docs/key-files.md)
- [`docs/naming-conventions.md`](./docs/naming-conventions.md)
- [`docs/architecture.md`](./docs/architecture.md)
- [`docs/git-conventions.md`](./docs/git-conventions.md)
- [`docs/app-store-setup.md`](./docs/app-store-setup.md)
