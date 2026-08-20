# Product direction

MacDjView is maintained as an independent downstream product.

## Project stance

- Optimize for the needs of this repository and its users, not for ease of merging changes back into `babanin/mac-djview`.
- Prefer native Apple platform integration and current Apple APIs where they materially improve the product.
- It is acceptable to change architecture, UI structure, build/release tooling, bundle identifiers, file layout, and internal APIs without preserving upstream compatibility.
- Keep changes reviewable and security-conscious: decoder/security work, UI work, system extensions, and rendering work should still be separated into focused pull requests.
- Preserve a clean Git history with one meaningful commit per small PR when practical.

## Platform targets

- macOS 14+ on Apple Silicon (`arm64` only).
- iOS/iPadOS 17+.
- Build and test with the current Xcode/SDK while keeping deployment targets tied to APIs actually used by the source.

## Product priorities

1. Safe, deterministic DjVu decoding.
2. Native document search using embedded `TXTa` / `TXTz` text.
3. Vision OCR fallback for pages without embedded text.
4. Native macOS integration: modern toolbar, Spotlight content indexing, Quick Look preview, and Finder thumbnails.
5. Performance work driven by Instruments measurements; prefer Apple frameworks before custom Metal code.

See [`roadmap.md`](./roadmap.md) for the implementation status and next steps.

## Upstream and licensing

This repository originated as a fork of `babanin/mac-djview`, but upstream mergeability is not a project requirement.

The upstream repository does not currently provide a LICENSE file and its README still contains a license TODO. Do not add a blanket project license or remove provenance/attribution on the assumption that the inherited code can be relicensed. If public redistribution terms need to be formalized, resolve the licensing status of inherited code first.
