---
description: Swift coding and security rules for MacDjView
alwaysApply: true
---
# Code best practices — MacDjView

## 1. Keep the decoder dependency-free

- The DjVu decoder/search core is pure Swift.
- `Package.swift` currently has no third-party dependencies.
- Prefer Foundation/CoreGraphics and Apple system frameworks for platform features.
- A new dependency needs a concrete product/performance/security justification; do not add one merely to avoid implementing a small bounded format component.

## 2. Treat DjVu input as untrusted

All parsing and decoding paths must preserve resource bounds.

- Use `ByteStream` throwing reads rather than unchecked offsets.
- Use `DecodeLimits.checkedAdd/checkedSubtract/checkedMultiply` for input-derived sizes/offsets.
- Validate dimensions/counts before allocation or nested work.
- Add a regression test for malformed input whenever a parser/security bug is fixed.
- System extensions (Spotlight/Quick Look) should use the same core plus tighter extension-specific work budgets.

Do not weaken a bound solely to accept one file; establish whether the file is valid/commonly accepted and preserve the security invariant around the relaxed edge case.

## 3. Format arithmetic

Some codec arithmetic intentionally relies on fixed-width wrapping behavior. Use wrapping operators only where required by the DjVu algorithm/reference semantics; use checked arithmetic for attacker-controlled sizes, counts, offsets, and allocations.

Do not generalize `&+`, `&-`, or `&*` into parser/resource accounting.

## 4. Coordinate systems

- DjVu image/JB2 source coordinates can be bottom-up.
- Rendered `CGImage`/SwiftUI page space is treated as top-down.
- Keep coordinate conversion at clear boundaries.
- `DjVuText` resolves text-zone rectangles into top-left page coordinates so UI search highlights can use them directly.

When changing rendering or text highlighting, test coordinate transforms independently from codec decode correctness.

## 5. Decoder state

Keep per-channel/per-codec mutable state isolated according to the format. In particular, IW44 color channels maintain independent decoder state while sharing the encoded bitstream where required.

Do not introduce shared mutable state between pages/channels merely as a performance optimization without proving thread-safety and format correctness.

## 6. Error handling

- Decoder/parser reads are throwing.
- Use `DjVuError` for format/decode/resource failures.
- Propagate deterministic decoder errors to the caller.
- UI layers may translate errors into user-facing messages, but should not silently reinterpret malformed input as valid data.
- Cancellation is not a decode failure; handle `CancellationError` separately in async UI work.

## 7. Search and text

- Embedded `TXTa` / `TXTz` text is the preferred source when available.
- Preserve original UTF-8 text/byte ranges for zone mapping; use normalized text only for search/index-friendly representations.
- Search result counts are bounded.
- Search work in the view model should remain debounceable/cancellable.
- Future Vision OCR belongs outside the deterministic DjVu parser and should be lazy/cached.

## 8. Concurrency and UI

- Keep expensive rendering/search/OCR off the main UI path.
- Cancel obsolete work when page/zoom/query state changes.
- Prefer SwiftUI system controls and platform APIs over custom AppKit/UIKit escape hatches unless a concrete behavior cannot be expressed cleanly.
- Use availability checks for newer macOS UI APIs while retaining the macOS 14 deployment target until source requirements change.

## 9. Performance

Measure before lowering abstraction level.

1. Establish a release-mode baseline with the CLI and Instruments.
2. Reduce unnecessary rerenders/allocations.
3. Prefer Core Animation/Core Image/Accelerate where appropriate.
4. Add raw Metal only if profiling shows it solves a remaining bottleneck.

Keep inner pixel/bitmap loops allocation-free where practical and maintain explicit memory/work limits.

## 10. Tests

Run:

```bash
make unit-test
swift run -c release MacDjView -- --test document.djvu
```

Tests should cover both valid representative documents and malformed boundary cases. Private/user documents may be used for local diagnosis, but should not be committed without explicit provenance/privacy review.

## 11. File organization

The codebase can grow when a new responsibility is real. Do not force unrelated platform/search/security code into existing files just to keep the file count small.

Prefer narrow files/modules with clear ownership:

- decoder/parser logic in `DjVu/`;
- platform/file-type integration near the app layer;
- UI/view-model code outside the decoder;
- future extension targets isolated from the main viewer where practical.
