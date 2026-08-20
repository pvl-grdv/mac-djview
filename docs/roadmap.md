# Platform integration roadmap

This document records the current product and architecture decisions for MacDjView. It is intentionally higher level than `architecture.md`, which documents the DjVu decoder itself.

## Supported platforms

- macOS 14+ on Apple Silicon (`arm64` only).
- iOS/iPadOS 17+.
- CI should use the current Xcode / SDK (currently Xcode 27 / iOS 27 SDK) without raising deployment targets unless the source actually requires newer APIs.
- Prefer native Apple frameworks and standard SwiftUI/AppKit integration before custom platform code.

## DjVu type declaration

The app currently references `org.djvu.djvu` in `CFBundleDocumentTypes`, but system integrations need the type to be explicitly declared.

Before adding Spotlight or Quick Look support, add a `UTImportedTypeDeclarations` entry for:

- UTI: `org.djvu.djvu`
- conforms to: `public.data`
- filename extensions: `djvu`, `djv`
- MIME type: `image/vnd.djvu` (IANA-registered)

The declaration should live in the generated app `Info.plist` so Launch Services, Spotlight and Quick Look agree on the same type.

## Text extraction and in-app search

### Embedded DjVu text first

DjVu can contain searchable text in `TXTa` (plain) and `TXTz` (BZZ-compressed) chunks. MacDjView already has a BZZ decoder, so the preferred search path is to add a bounded parser for these chunks rather than running OCR on every page.

The text parser should preserve page association and DjVu text-zone coordinates where available. This enables:

- `Command-F` / native search field;
- fast document-wide search;
- next/previous match navigation;
- page-level results;
- match highlighting on the rendered page.

A representative 192-page DjVu examined during development contained `TXTz` on 190 pages, so embedded text is expected to cover most search work for many real documents.

### Vision OCR fallback

For pages without embedded text, use Apple's Vision text-recognition APIs as an optional fallback.

- Query `supportedRecognitionLanguages` at runtime instead of assuming a fixed list.
- Prefer `ru-RU` and `en-US` when supported for Russian/English documents.
- Use accurate recognition for explicit document search / OCR work.
- OCR should be lazy, cancellable and cached; do not OCR an entire large document just because it was opened.
- Keep OCR outside the decoder core so DjVu parsing remains deterministic and testable.

Vision OCR is an app feature, not a prerequisite for basic DjVu support.

## macOS Spotlight content indexing

### Supported macOS integration: Spotlight importer plug-in

For system-wide macOS search of arbitrary `.djvu` files, use a Spotlight metadata importer (`.mdimporter`) bundled inside:

`MacDjView.app/Contents/Library/Spotlight/`

This remains Apple's documented integration for custom file formats on macOS. The current `CSImportExtension` documentation explicitly states that Spotlight File Import extensions do not provide this functionality on macOS and directs Mac developers to a Spotlight importer plug-in instead.

The importer should claim `org.djvu.djvu`, parse the document with strict resource limits, and populate standard Spotlight metadata, especially:

- `kMDItemTextContent` — combined embedded `TXTa` / `TXTz` text;
- `kMDItemNumberOfPages` — page count;
- `kMDItemTitle` when a reliable document title exists;
- standard language / author / subject keys only when corresponding DjVu metadata is actually available.

`kMDItemTextContent` is intended for the text representation supplied by a Spotlight importer. Spotlight can search it even though applications cannot read that attribute back directly.

### Core Spotlight and CSImportExtension

Use modern Core Spotlight APIs where they are actually supported and appropriate, but do not substitute them for the macOS file-format importer:

- `CSImportExtension` is the modern Spotlight File Import extension API, but Apple's current documentation explicitly says it does not provide the custom-file importing functionality on macOS.
- `CSSearchableIndex` remains useful for app-owned or app-generated searchable entities.
- Core Spotlight may be considered later for OCR results or other app-owned data associated with documents the user explicitly opened.
- A sandboxed viewer must not crawl the user's disk to build a parallel index of arbitrary DjVu files.

If Apple changes the macOS support status of `CSImportExtension` in a future SDK, reevaluate this decision against the then-current documentation and a real-device/macOS test before migrating.

### Importer performance and security rules

The importer runs automatically under Spotlight workers, so it must be much cheaper than the full viewer:

- extract metadata and embedded text only;
- do not render pages;
- do not run Vision OCR automatically in the importer;
- enforce the same file/chunk/text limits as the decoder, plus importer-specific text-size/work budgets;
- return partial safe metadata rather than doing expensive recovery work;
- never use network access.

Testing should include:

```bash
mdimport -L
mdimport -t -d3 sample.djvu
mdls sample.djvu
mdfind "a known phrase from the DjVu"
```

When the importer changes, reimport the claimed UTI/importer and verify that the expected file is found by normal Finder/Spotlight search.

References:

- https://developer.apple.com/documentation/corespotlight/csimportextension
- https://developer.apple.com/library/archive/documentation/Carbon/Conceptual/MDImporters/Concepts/WritingAnImp.html
- https://developer.apple.com/library/archive/documentation/Carbon/Conceptual/MDImporters/Concepts/AssigningDataToAttrs.html
- `man mdimport`
- IANA media types: https://www.iana.org/assignments/media-types/media-types.xhtml

## Quick Look and Finder thumbnails

Add native system extensions for DjVu:

1. Quick Look preview: show a lightweight document preview when the user presses Space in Finder.
2. Thumbnail provider: render a small first-page thumbnail for Finder.

Both should reuse the safe decoder with extension-specific limits. They should decode only what is needed for the requested preview and must not index/OCR the full document.

These integrations depend on the correct DjVu UTI declaration above.

## macOS 27 UI

Modernize the macOS toolbar using standard SwiftUI toolbar controls rather than custom glass chrome.

Desired structure on current macOS:

- previous / next page as one leading system group;
- page indicator as a quiet standalone item;
- compact view-mode menu instead of two wide segmented pickers;
- zoom controls grouped together;
- fit-to-height and color theme as distinct actions;
- native `searchable` / search toolbar behavior for document text search;
- `ToolbarSpacer` to define logical groups on modern macOS;
- let the system provide Liquid Glass rather than applying custom blur/backgrounds to standard toolbar items.

Keep version-specific toolbar APIs behind `#available` and retain a sensible macOS 14 fallback.

## Rendering and GPU strategy

Do not introduce raw Metal merely because it is available.

Current priorities:

1. Avoid unnecessary full-page rerenders for every interactive zoom change.
2. Profile decoding, composition, scrolling and memory with Instruments.
3. Prefer system acceleration (Core Animation / Core Image / Accelerate-vImage) when it solves the measured bottleneck.
4. Consider a Metal tile/compositor path only if profiling shows the CPU `PageCompositor` or very large-page scrolling remains a real bottleneck.

The entropy / format decoders (BZZ, ZP, JB2, much of IW44) remain CPU-oriented. GPU work is most promising for layer composition, scaling, themes and visible-tile rendering, not for rewriting the whole codec stack.

MetalFX is not currently justified for a document viewer.

## Recommended implementation order

1. Correct DjVu UTI declaration.
2. `TXTa` / `TXTz` parser with resource limits and tests.
3. In-app `Command-F` search and result navigation/highlighting.
4. Vision OCR fallback for pages without text.
5. Modern macOS toolbar/search presentation with macOS 14 fallback.
6. macOS Spotlight `.mdimporter` using embedded text only.
7. Quick Look preview and Finder thumbnail support.
8. Instruments profiling of zoom/scroll/compositor.
9. Core Image / Accelerate optimizations where measured.
10. Metal tile renderer only if measurements justify it.

## Release discipline

Keep decoder/security fixes, system integrations, UI changes and rendering optimizations in separate focused PRs. Preserve the existing preference for one meaningful commit per small PR when practical. Do not raise minimum OS versions merely because CI uses a newer SDK.
