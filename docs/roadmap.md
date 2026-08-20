# Platform integration roadmap

This document tracks product/platform work for the independent MacDjView downstream. Decoder internals are documented in [`architecture.md`](./architecture.md); project stance is in [`product-direction.md`](./product-direction.md).

## Supported platforms

- macOS 14+ on Apple Silicon (`arm64` only).
- iOS/iPadOS 17+.
- CI should use the current Xcode/SDK without raising deployment targets unless the source actually requires newer APIs.
- Prefer native Apple frameworks and standard SwiftUI/AppKit integration before custom platform code.

## Current implementation status

Completed:

- DjVu UTI declaration: `org.djvu.djvu`, `.djvu` / `.djv`, `image/vnd.djvu`.
- Bounded `TXTa` / `TXTz` decoding using the existing BZZ decoder.
- UTF-8 byte ranges and DjVu text-zone coordinates.
- Bounded document-wide embedded-text search.
- Native SwiftUI `.searchable` UI.
- macOS `Command-F`, `Command-G`, and `Shift-Command-G` find commands.
- Search-result navigation and text-zone highlighting in paged, continuous, and two-page layouts.

Next major work:

1. Vision OCR fallback for pages without embedded text.
2. Modern macOS toolbar/search presentation with macOS 14 fallback.
3. macOS Spotlight content importer.
4. Quick Look preview and Finder thumbnails.
5. Instruments-driven rendering/zoom optimization.

## DjVu type declaration

The generated macOS `Info.plist` already imports `org.djvu.djvu` with:

- conforms to: `public.data`;
- filename extensions: `djvu`, `djv`;
- MIME type: `image/vnd.djvu`.

The app also exposes `UTType.djvu` in Swift. Future Spotlight/Quick Look components should use the same identifier so Launch Services and extensions agree on the file type.

## Text extraction and in-app search

### Embedded text — implemented

DjVu text is decoded from `TXTa` and BZZ-compressed `TXTz` chunks. The parser is bounded by dedicated text-size, zone-count, and zone-depth limits and preserves the original UTF-8 byte ranges plus zone coordinates.

Search currently:

- runs over embedded DjVu text only;
- is case/diacritic insensitive through Foundation string search behavior chosen by the search engine;
- is debounced and cancellable from the view model;
- caps result count;
- navigates to the matching page;
- highlights the selected result using text-zone rectangles.

A representative 192-page DjVu examined during development contained `TXTz` on 190 pages, so embedded text is expected to cover most searches for many real documents.

### Vision OCR fallback — next

For pages without embedded text, add Apple's Vision text-recognition APIs as an optional fallback.

Requirements:

- query supported recognition languages at runtime;
- prefer `ru-RU` and `en-US` when supported;
- use accurate recognition for explicit document-search/OCR work;
- OCR lazily and cancellably rather than scanning a whole document on open;
- cache page OCR results within an appropriate lifetime/budget;
- map recognized bounding boxes into the same page-coordinate model used by search highlighting;
- keep OCR outside the deterministic DjVu decoder core.

Embedded DjVu text remains authoritative when present; OCR should fill missing pages rather than replace good `TXTa` / `TXTz` data.

## macOS Spotlight content indexing

### Supported macOS path

For system-wide macOS search of arbitrary `.djvu` files, use a Spotlight metadata importer (`.mdimporter`) bundled inside:

`MacDjView.app/Contents/Library/Spotlight/`

Current Apple documentation for `CSImportExtension` explicitly states that the custom-file import functionality is not provided on macOS and directs Mac developers to a Spotlight importer plug-in. Reevaluate only if Apple changes that support status in a future SDK.

The importer should claim `org.djvu.djvu` and expose standard Spotlight metadata, especially:

- `kMDItemTextContent` — combined embedded `TXTa` / `TXTz` text;
- `kMDItemNumberOfPages` — page count;
- title/author/subject only when reliable DjVu metadata actually exists.

Do not run Vision OCR automatically inside Spotlight workers. The importer should extract embedded text/metadata only, with stricter work budgets than the viewer and no network access.

Validation should include:

```bash
mdimport -L
mdimport -t -d3 sample.djvu
mdls sample.djvu
mdfind "a known phrase from the DjVu"
```

## Quick Look and Finder thumbnails

Add native system extensions for `org.djvu.djvu`:

- Quick Look preview for Space/Finder preview.
- Thumbnail provider for Finder thumbnails.

Both should reuse the bounded decoder with extension-specific limits and decode only what is necessary. First-page rendering is the default strategy; neither extension should OCR/index the whole document.

## macOS 27 UI

Modernize the macOS toolbar using standard SwiftUI toolbar behavior rather than hand-built glass chrome.

Target structure:

- previous/next grouped as navigation controls;
- quiet page indicator;
- compact view-mode menu instead of wide segmented pickers;
- grouped zoom controls;
- distinct fit-to-height and color-theme actions;
- native search presentation;
- `ToolbarSpacer` on newer macOS where available;
- system-provided Liquid Glass rather than custom blur/backgrounds for normal toolbar controls.

Keep newer toolbar APIs behind availability checks and retain a sensible macOS 14 fallback.

## Rendering and GPU strategy

Do not introduce raw Metal simply because Apple Silicon supports it.

Priority order:

1. Avoid unnecessary full-page rerenders during interactive zoom.
2. Profile decoding, composition, scrolling, zoom, and memory with Instruments.
3. Prefer Core Animation / Core Image / Accelerate-vImage when they solve the measured bottleneck.
4. Consider a Metal tile/compositor path only if profiling shows the CPU compositor or very-large-page scrolling remains a material bottleneck.

Entropy/format decoding (BZZ, ZP, JB2, much of IW44) remains CPU-oriented. GPU work is most promising for composition, scaling, themes, and visible-tile rendering. MetalFX is not currently justified.

## Implementation order from current main

1. Vision OCR fallback for pages without embedded text.
2. Modern macOS toolbar/search presentation.
3. Spotlight `.mdimporter` using embedded text only.
4. Quick Look preview and Finder thumbnail support.
5. Instruments profiling of zoom/scroll/compositor.
6. Core Image / Accelerate optimizations where measured.
7. Metal tile renderer only if measurements justify it.

## Release discipline

Keep decoder/security fixes, OCR, system integrations, UI changes, and rendering optimizations in separate focused PRs. Prefer one meaningful commit per small PR. Upstream mergeability is not a constraint, but reviewability, security boundaries, and deployment-target discipline still are.
