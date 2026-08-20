---
description: Project structure and key files reference
alwaysApply: true
---
# Key files

## Project layout

```text
mac-djview/
├── Package.swift
├── CLAUDE.md
├── MacDjView.entitlements
├── Resources/
│   └── AppIcon.icon/                    # Icon Composer source
├── Sources/MacDjView/
│   ├── MacDjViewApp.swift               # SwiftUI App entry, commands, CLI --test
│   ├── AppDelegate.swift                # macOS delegate, URL opening, settings
│   ├── ContentView.swift                # Main viewer, toolbar, native search field
│   ├── DocumentViewModel.swift          # Document/view/search state
│   ├── PageImageView.swift              # Single/two/continuous pages, cache, highlights
│   ├── Platform.swift                   # NSImage/UIImage bridge
│   ├── SafeFileLoader.swift             # Bounded document reads
│   ├── DjVuUTType.swift                 # org.djvu.djvu UTType
│   ├── PrivacyInfo.xcprivacy            # Privacy manifest
│   └── DjVu/
│       ├── DecodeLimits.swift            # Central resource/work limits
│       ├── ByteStream.swift              # Bounds-checked binary reader
│       ├── IFFParser.swift               # Bounded IFF parser
│       ├── DjVuDocument.swift            # Multi-page document, DIRM, text access
│       ├── DjVuPage.swift                # Per-page image/text layer access
│       ├── DjVuText.swift                # TXTa/TXTz + text-zone parser
│       ├── DjVuSearch.swift              # Bounded embedded-text search
│       ├── DjVuError.swift
│       ├── ZPCodec.swift
│       ├── BZZDecoder.swift
│       ├── IW44Decoder.swift
│       ├── IW44Image.swift
│       ├── IW44Structures.swift
│       ├── JB2Decoder.swift
│       ├── JB2Dict.swift
│       ├── JB2Image.swift
│       ├── JB2Structures.swift
│       └── PageCompositor.swift
├── Tests/MacDjViewTests/                # Decoder/safety/text/search/render tests
├── docs/
│   ├── product-direction.md              # Independent downstream stance
│   ├── roadmap.md                        # Current platform work/status
│   ├── architecture.md                   # Decoder/text architecture
│   └── ...                               # Coding and Git conventions
└── scripts/
    ├── make-app-bundle.sh                # arm64 .app, icon, plist, ad-hoc signing
    └── run-tests.sh
```

## Important runtime boundaries

- `SafeFileLoader` is the first file-size boundary.
- `IFFParser` and `DecodeLimits` protect the decoder from malformed structure/work amplification.
- `DjVuDocument` owns page enumeration and shared dictionaries.
- `DjVuPage` exposes deterministic image and embedded-text decoding.
- `DjVuText` and `DjVuSearch` do not depend on SwiftUI.
- `DocumentViewModel` owns UI-facing async/cancellable search and rendering state.
- `PageImageView` draws search highlights as UI overlays rather than modifying decoded page pixels.

## Build and run

| Command | Purpose |
|---|---|
| `swift build` | Debug SwiftPM build |
| `swift build -c release` | Release SwiftPM build |
| `swift run MacDjView` | Launch the executable app |
| `swift run -c release MacDjView -- --test file.djvu` | Headless decode/render test |
| `make unit-test` | Run test suite |
| `./scripts/make-app-bundle.sh` | Build/sign arm64 macOS app bundle |

The packaged macOS app requires full Xcode because `actool` compiles `Resources/AppIcon.icon` into `Assets.car` and `AppIcon.icns`.

## Reference implementations

Reference implementations can help resolve format questions, but tests and the DjVu format behavior are authoritative for this codebase. Do not copy behavior blindly when it weakens bounds checking or conflicts with known valid files.
