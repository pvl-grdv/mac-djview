---
description: Naming patterns used throughout the codebase
alwaysApply: true
---
# Naming conventions

## Swift files and types

- Swift files and nominal types use PascalCase: `DjVuDocument.swift`, `DjVuTextLayer`, `DocumentViewModel`.
- Methods/properties/local values use lower camel case.
- Keep standard Apple/format initialisms recognizable: `URL`, `UTF8`, `CGImage`, `IW44`, `JB2`, `BZZ`, `ZP`.

Codec files generally follow responsibility-oriented names:

- `*Decoder.swift` — encoded stream/codec logic;
- `*Image.swift` — reconstructed image/bitmap representation;
- `*Structures.swift` — format support types;
- purpose-specific components use explicit names such as `DjVuText.swift`, `DjVuSearch.swift`, and `DecodeLimits.swift`.

## Format names

Names that mirror the DjVu format/reference implementation may be retained when they make codec auditing easier (`quantLo`, `curband`, context-array names, etc.). Do not preserve an awkward upstream/reference name outside codec internals when a clearer Swift/product name is better.

Upstream mergeability is not a naming constraint.

## DjVu chunk IDs

Chunk IDs are four-character case-sensitive strings from the file format, for example:

- `BG44`, `FG44` — IW44 image layers;
- `Sjbz` — JB2 page mask;
- `Djbz` — shared JB2 dictionary;
- `FGbz` — foreground palette;
- `INFO` — page metadata;
- `DIRM` — multi-page directory;
- `INCL` — shared-data reference;
- `TXTa`, `TXTz` — hidden text (plain/compressed).

FORM types include `DJVM` (multi-page), `DJVU` (page), and `DJVI` (shared data).

## Units and coordinate names

Include units/space in names when ambiguity matters, especially across rendering/text code:

- `pageIndex`, `pageHeight`;
- `textByteRange` for UTF-8 byte offsets;
- `zoomPercent` for integer cache keys;
- `nativePageSize` for unscaled page dimensions.

Do not call byte offsets `String.Index` values or mix DjVu bottom-up coordinates with top-left UI coordinates under the same ambiguous name.

## Limits

Security/work limits belong under `DecodeLimits` and use descriptive lower-camel static names such as `maxFileBytes`, `maxTextZonesPerPage`, and `maxSearchResults`.

## UI/product naming

Use Apple terminology for native platform concepts where practical (`searchable`, Quick Look, Spotlight importer, thumbnail provider). Use `MacDjView` for the current product/module name unless a deliberate product rename is made across bundle metadata, docs, and release tooling together.
