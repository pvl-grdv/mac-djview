# MacDjView

MacDjView is a native macOS/iPadOS reader for DjVu documents and CBR comics. DjVu decoding is implemented in pure Swift; CBR support uses the Unrar Swift package. The UI uses Apple's SwiftUI and ImageIO frameworks.

This repository is maintained as an independent downstream product. See [Product direction](docs/product-direction.md) and the [Platform integration roadmap](docs/roadmap.md).

![MacDjView screenshot](docs/screenshot.png)

## Current features

- Pure-Swift DjVu decoding: IFF, BZZ, ZP-Coder, IW44, JB2, palettes, shared dictionaries, and page composition.
- Multi-page documents with single-page, two-page, paged, and continuous viewing modes.
- Read-only CBR comic support (RAR/RAR5 with JPEG, PNG, and other ImageIO images), including on iPad.
  CBR files are read lazily; encrypted and multi-volume archives are not supported.
- App Sandbox with read-only access to user-selected files and no network entitlement.
- Apple Silicon macOS application bundle (`arm64` only).
- Imported DjVu type declaration: `org.djvu.djvu` for `.djvu` / `.djv` and `image/vnd.djvu`.
- Embedded DjVu text decoding from `TXTa` and `TXTz` chunks with bounded resource usage.
- Native document search using SwiftUI `.searchable`.
- macOS find commands: `Command-F`, `Command-G`, and `Shift-Command-G`.
- Search-result navigation and page highlighting using DjVu text-zone coordinates.
- Icon Composer app icon compiled into `Assets.car` with an ICNS fallback.
- Headless decode/render performance mode via `--test`.

Not implemented yet: Vision OCR fallback, Spotlight content importer, Quick Look preview, Finder thumbnails, and the planned modern toolbar refresh. Their status is tracked in [`docs/roadmap.md`](docs/roadmap.md).

## Requirements

- macOS 14 (Sonoma) or later on Apple Silicon (`arm64`).
- iOS/iPadOS 17 or later, including iPad Pro 10.5-inch (2017).
- Swift tools 5.10+.
- CBR handling uses the SwiftPM `Unrar.swift` dependency and its bundled UnRAR decompressor;
  see the dependency's distinct UnRAR license terms. DjVu decoding remains dependency-free.
- Full Xcode is required for the packaged macOS app because the Icon Composer source is compiled with `actool`.

CI can use newer Xcode/SDK releases without raising the deployment targets unless the source actually adopts APIs that require a newer OS.

## Building

```bash
# Debug build
swift build

# Release build
swift build -c release

# Run directly
swift run MacDjView

# Create the arm64 macOS .app bundle
./scripts/make-app-bundle.sh
```

### macOS

Use `Package.swift` for SwiftPM testing and the macOS build script above to make the app bundle. The GitHub Actions workflow produces a macOS arm64 archive on successful runs.

### iPadOS (no paid Apple Developer membership needed)

**Open [ios/MacDjView-iOS.xcodeproj](ios/MacDjView-iOS.xcodeproj) in Xcode 27** and choose the shared **MacDjView-iPad** scheme. This is an actual iPad/iPhone app target; building the `Package.swift` executable by itself does **not** produce an installable iOS app. The project shares the Swift source files with the macOS SwiftPM target.

To run it on your own iPad: add your Apple Account in Xcode Settings → Accounts, select your **Personal Team** under Signing & Capabilities, connect the unlocked iPad and trust your Mac, select it as the run destination, and press **Run (⌘R)**. Enable Developer Mode on the iPad if prompted. A Personal Team app must be re-provisioned/reinstalled after seven days. Details and troubleshooting: [Install on iPad without a paid account](docs/ipad-installation.md).

Once installed, tap the folder button and select a `.cbr` or `.djvu` book from Files. On Mac use **File → Open…** or drop a file into the reader. CI verifies an **unsigned** iPadOS 17-compatible `.app` bundle; it cannot sign for your Personal Team and does not publish a usable `.ipa` or TestFlight build.

## macOS releases and Gatekeeper

GitHub release builds contain an Apple Silicon `MacDjView-macOS-arm64.app.zip` plus a SHA-256 checksum. The app is ad-hoc signed with App Sandbox entitlements, but is not Developer ID notarized.

Before overriding Gatekeeper, verify the archive and signature:

```bash
shasum -a 256 -c MacDjView-macOS-arm64.app.zip.sha256
unzip MacDjView-macOS-arm64.app.zip
codesign --verify --strict --verbose=2 MacDjView.app
codesign -dvvv --entitlements :- MacDjView.app
```

The entitlements should include `com.apple.security.app-sandbox` and `com.apple.security.files.user-selected.read-only`, and should not include network client/server entitlements.

After verification, use **Finder → right-click MacDjView.app → Open** or **System Settings → Privacy & Security → Open Anyway**. For a copy you have independently verified, the command-line equivalent is:

```bash
xattr -dr com.apple.quarantine MacDjView.app
```

Do not remove quarantine from an app you have not verified.

## Tests

```bash
make unit-test
# or
./scripts/run-tests.sh
```

Tests cover binary bounds checking, decoder safety limits, IFF parsing, wavelet and compositor behavior, embedded DjVu text decoding, Unicode/text-zone handling, and document search.

CI runs for pull requests, pushes to `main`, and version tags. The macOS job runs unit tests, builds the arm64 app, validates sandbox entitlements, and packages the release artifact. The iPadOS job builds an actual unsigned `.app` for arm64 and verifies its `MinimumOSVersion = 17.0` and DjVu/CBR file type registrations. PR builds are cancellable when superseded. Only macOS is published in Releases; the iPad app is locally signed with a free Apple Account.

[Compatibility and WWDC24–26 choices](docs/compatibility.md) explains which APIs we intentionally use and why we keep older OS fallbacks.

## CLI decode/performance testing

The `--test` flag renders pages headlessly and reports timing and memory usage:

```bash
swift run -c release MacDjView -- --test document.djvu
swift run -c release MacDjView -- --test document.djvu 100
```

The optional page argument is zero-based. For performance work, compare p95 render time and peak resident memory rather than relying on debug builds.

## Project structure

```text
Sources/MacDjView/
├── MacDjViewApp.swift        # App entry point, commands, CLI --test mode
├── AppDelegate.swift         # macOS delegate, open-URL handling, settings
├── ContentView.swift         # Main SwiftUI view, toolbar, search presentation
├── DocumentViewModel.swift   # Document/view/search state and navigation
├── PageImageView.swift       # Page views, cache, search highlights
├── Platform.swift            # macOS/iOS image and color bridge
├── SafeFileLoader.swift      # Bounded file loading
├── DjVuUTType.swift          # org.djvu.djvu Uniform Type declaration
├── PrivacyInfo.xcprivacy     # Privacy manifest
└── DjVu/
    ├── DjVuDocument.swift    # Document parsing, page access, embedded text
    ├── DjVuPage.swift        # Per-page layer/text decoding
    ├── DjVuText.swift        # TXTa/TXTz text and text-zone parser
    ├── DjVuSearch.swift      # Bounded document-wide embedded-text search
    ├── DecodeLimits.swift    # Central resource/work limits
    ├── IFFParser.swift       # Bounded IFF parser
    ├── ByteStream.swift      # Bounds-checked binary reader
    ├── BZZDecoder.swift      # BZZ decoder
    ├── ZPCodec.swift         # ZP arithmetic decoder
    ├── IW44*.swift           # Wavelet decode/reconstruction
    ├── JB2*.swift            # JB2 bitmap/symbol decoding
    └── PageCompositor.swift  # Layer composition to CGImage

ios/MacDjView-iOS.xcodeproj/ # iPadOS app target (Personal Team signing)
Resources/AppIcon.icon/       # Icon Composer source
Tests/MacDjViewTests/         # Decoder, safety, text, search, rendering tests
docs/                         # Architecture, project direction, roadmap, conventions
scripts/                      # Bundle/test/release helpers
```

## Development workflow

- Work from short-lived topic branches and merge focused PRs with rebase when practical.
- Prefer one meaningful commit per small PR.
- Decoder/security changes, platform integrations, UI changes, and rendering optimizations should remain separable.
- Prefer native Apple frameworks and system behavior before custom platform code.
- Upstream mergeability is not a design requirement for this repository.

See [`docs/git-conventions.md`](docs/git-conventions.md) and [`docs/product-direction.md`](docs/product-direction.md).

## Licensing / provenance

This repository originated as a fork of `babanin/mac-djview`. The upstream repository currently does not contain a LICENSE file and its README also leaves licensing unresolved. This repository therefore does not claim a new blanket license for inherited code. Resolve the rights/provenance of inherited code before publishing a project-wide license or making licensing-sensitive distribution decisions.
