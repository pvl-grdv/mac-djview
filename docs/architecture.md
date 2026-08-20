---
description: Decoder architecture and DjVu format reference
alwaysApply: true
---
# Architecture — DjVu decoder and text pipeline

## High-level pipeline

```text
DjVu file
  │
  ├── SafeFileLoader                    bounded file read
  │
  ├── IFFParser.parse()                 bounded FORM/chunk tree
  │
  └── DjVuDocument
        │
        ├── page metadata / shared dictionaries
        │
        ├── DjVuPage.render()           image pipeline
        │     ├── BG44 / FG44 → IW44
        │     ├── Sjbz / Djbz → JB2
        │     ├── FGbz → palette
        │     └── PageCompositor → CGImage
        │
        └── DjVuPage.textLayer()        text pipeline
              ├── TXTa → direct payload
              └── TXTz → bounded BZZ decode
                    ↓
                 DjVuTextLayer
                    ├── UTF-8 text
                    └── text-zone hierarchy / page rectangles
                          ↓
                      DjVuSearch
```

The deterministic DjVu decoder/text parser is kept separate from platform features such as SwiftUI search presentation, Vision OCR, Spotlight, and Quick Look.

## Security / resource model

Input files are untrusted. Decoder limits are centralized in `DecodeLimits.swift` and are applied before allocations or expensive work where practical.

Key protections include:

- bounded file size;
- checked integer arithmetic;
- bounded IFF lengths, nesting depth, and chunk count;
- bounded page dimensions and rendered pixel counts;
- bounded IW44 block/slice work;
- bounded JB2 symbols, blits, bitmap pixels, records, comments, and blit work;
- bounded BZZ output;
- dedicated text-byte, text-zone count/depth, document-text, and search-result limits.

System extensions (Spotlight/Quick Look) should reuse this core but impose tighter extension-specific work limits because they can be invoked automatically by macOS.

## Embedded DjVu text

`DjVuText.swift` decodes page hidden text from:

- `TXTa`: uncompressed text payload;
- `TXTz`: BZZ-compressed text payload.

The payload begins with a 24-bit UTF-8 text length and can optionally contain a versioned text-zone hierarchy. Text zones preserve:

- kind (`page`, `column`, `region`, `paragraph`, `line`, `word`, `character`);
- page-space rectangle;
- UTF-8 byte range in the original page text;
- child zones.

DjVu zone coordinates are delta-encoded. The parser resolves them into top-left page coordinates matching rendered image/UI space so the same rectangles can be used for search highlighting.

Structural DjVu text separators are normalized only for search/index-friendly `plainText`; original text remains unchanged so zone byte ranges stay valid.

## Document search

`DjVuSearch.swift` searches embedded page text and returns bounded result objects containing:

- page index;
- matched UTF-8 byte range;
- matching text-zone rectangles.

`DocumentViewModel` debounces/cancels search work and controls the selected result. `ContentView` uses native SwiftUI `.searchable`, while page views overlay the selected zone rectangles without mutating the rendered DjVu image.

OCR is intentionally outside this pipeline. Future Vision OCR results should be converted into a compatible page-text/result model rather than being embedded into the DjVu decoder.

## IW44 wavelet decoder

### Chunk header (BG44/FG44)

```text
Byte 0:    serial (uint8) — 0 for first chunk
Byte 1:    numSlices (uint8)
If serial == 0:
  Byte 2:  majver (uint8) — bit 7: grayscale flag
  Byte 3:  minver (uint8)
  Byte 4-5: width (uint16 big-endian)
  Byte 6-7: height (uint16 big-endian)
  Byte 8:  delayInit
```

### Channel architecture

- Separate `IW44ChannelDecoder` state for Y, Cb, and Cr.
- Each channel has independent band/quantization/context/coefficient state.
- Channels share the same ZP bitstream.
- `delayInit` delays chroma decoding; Y begins immediately.

### Decode phases

1. Preliminary coefficient classification.
2. Block-band activation.
3. Bucket activation.
4. Newly active coefficient values.
5. Refinement of previously active coefficients.

### Inverse wavelet transform

- Four-level lifting-based DDL 4,4 wavelet.
- Operates on `LinearBytemap` with format-appropriate wrapping arithmetic.
- Processes columns then rows at successive scale levels.

## JB2 symbol decoder

### Init sequence

1. Decode record type.
2. If record 9: decode inherited dictionary size and next record.
3. Decode image width/height.
4. Decode the flag with the raw ZP bit path required by the format.

### Record types

| Type | Description |
|---|---|
| 1 | New direct symbol + library + blit |
| 2 | New direct symbol + library |
| 3 | New direct symbol + blit |
| 4 | Refined symbol + library + blit |
| 5 | Refined symbol + library |
| 6 | Refined symbol + blit |
| 7 | Matched copy blit |
| 8 | Non-symbol data / absolute coordinates |
| 9 | Numcoder reset |
| 10 | Comment |
| 11 | End of data |

JB2 source coordinates are bottom-up. Coordinate conversion to top-down display space occurs at the rendering/text-boundary layers rather than being mixed throughout codec logic.

## ZP-Coder

- Adaptive binary arithmetic coding with a probability-state table.
- Context-coded single-bit decode for format state.
- Context-free IW decode path where required.
- Number decoding uses `NumContext` trees.

## Page composition

The compositor combines layers at the requested render scale:

1. IW44 background.
2. Optional IW44/palette foreground.
3. JB2 mask.
4. Mask chooses foreground vs background pixels.
5. Output is a top-down `CGImage` for SwiftUI/AppKit/UIKit display.

The current compositor is CPU-based. Rendering optimization should be measurement-driven; see `roadmap.md` for the Core Image/Accelerate/Metal strategy.
