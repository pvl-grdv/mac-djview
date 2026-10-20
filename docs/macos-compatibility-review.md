# macOS minimum version and 2024–2026 UI review

## Decision: retain macOS 14 Sonoma as the minimum

The current app is a read-only DjVu/CBR reader with a pure-Swift DjVu
decoder and native SwiftUI views. Its state model uses the Observation
framework (`@Observable` + `@State`), supported in SwiftUI starting with
**macOS 14** and iPadOS 17.

- **macOS 13** would require migrating to / supporting the older
  `ObservableObject` and `@StateObject` model. That brings a second
  state-management strategy without helping reading or decoding.
- **macOS 14** provides a clean shared baseline with iPadOS 17.
- **macOS 15/26/27** add optional UI capabilities, but requiring them would
  unnecessarily exclude machines that can already read our documents.
- Users of **macOS 27.2** automatically get the native appearance of system
  controls when running a modern build. Do not paint custom glass surfaces.

Deployment floors remain in `Package.swift` (macOS 14, iOS 17), the macOS
app-bundling script (`LSMinimumSystemVersion=14.0`), and iPadOS Xcode target
(`IPHONEOS_DEPLOYMENT_TARGET=17.0`, in PR #13).

## What we applied

### WWDC24 — SwiftUI windowing and content updates

[What's new in SwiftUI (WWDC24, session 10144)](https://developer.apple.com/videos/play/wwdc2024/10144/)

- A document opened from Finder deserves its own native window, not a global
  singleton's one mutable `pendingURL`. Buffer early open events and open
  one `WindowGroup(for: URL.self)` window per file.
- Keep one observable document view model **per window**. Page cache, search
  and reading progress should not be shared across independent documents.
- Use SwiftUI's existing view lifecycle and `ScrollViewReader`; do not force
  iOS 18/macOS 15 scrolling APIs to support earlier OS versions.

### WWDC25 — system controls and platform appearance

[Build a SwiftUI app with the new design (WWDC25, session 323)](https://developer.apple.com/videos/play/wwdc2025/323/)

- Use ordinary SwiftUI toolbars, menus, search and buttons. On newer macOS
  versions these adopt the OS appearance; we do not create a second design
  system or make the book page translucent.
- Compact the primary reading-layout controls into a single system menu.
  Reserve toolbar space for page navigation, search and frequently used zoom.
- Provide equivalent keyboard/menu commands for toolbar actions.

### WWDC26 — new APIs where useful, not where they break compatibility

[What's new in SwiftUI (WWDC26, session 269)](https://developer.apple.com/videos/play/wwdc2026/269/)

- The expanded Document API, toolbar visibility priority and other 2027
  system APIs are **optional**. A read-only viewer targeting macOS 14 and
  iPadOS 17 does not require a full document-system rewrite.
- Keep existing `fileImporter` for explicit user-selected access.
- Separate presentation zoom from image decoding quality. On Mac, reuse
  0.5× or 1× bitmaps and let SwiftUI display them at the requested scale,
  instead of decoding every 25%-increment.
- In CBR continuous mode, use fixed, aspect-fit reading slots until each
  image has been lazily decoded, preventing scroll-position jumps.

### HIG: window identity, toolbar, search and loading

- [Designing for macOS](https://developer.apple.com/design/human-interface-guidelines/designing-for-macos/)
  — native windows, keyboard and pointer use, menu bar, full screen.
- [Windows](https://developer.apple.com/design/human-interface-guidelines/windows)
  — independent document windows, useful titles and standard resizing.
- [Toolbars](https://developer.apple.com/design/human-interface-guidelines/toolbars)
  — concise, grouped items and a menu-bar equivalent for toolbar commands.
- [Searching](https://developer.apple.com/design/human-interface-guidelines/searching)
  — one predictable system search field with standard Find shortcuts.
- [Loading](https://developer.apple.com/design/human-interface-guidelines/loading)
  — bounded off-main-thread decoding and standard progress UI rather than
  blocking the entire window.

## Deliberately not part of this reliability change

- Quick Look and Finder thumbnail extensions (require separate, bundled
  system extensions and extra code-signing tests).
- Vision OCR, Spotlight indexing and CBZ (separate format/system projects).
- Custom Metal, custom Liquid Glass and macOS 27-only toolbars.
- Replacing SwiftPM with a large Xcode-only macOS project or requiring a
  paid Apple Developer Program membership.

## How to verify

Run `swift test` and `./scripts/make-app-bundle.sh` on macOS, then use
`open MacDjView.app`. GitHub Actions also tests and packages macOS arm64 and
compiles the iPadOS 17 target.

**Manual desktop smoke test:**

1. Open two different files together from Finder. Both should appear in
   separate windows and keep independent page, search and zoom state.
2. Open a file while the app is launching. The first URL must not disappear.
3. Quickly flip among pages while a slow scan is being decoded. The image
   shown must always match the selected page.
4. Zoom from 100% to 125% to 200%; the view should resize without repeated
   full-page decode at every step.
5. Open a mixed-aspect-ratio CBR in continuous view. Its page slots remain
   stable during lazy extraction; images are letterboxed without cropping.
6. Verify Fit to Width (⌘8), Fit to Height (⌘9), Cmd-F and the View menu.
7. Launch on macOS 14 as well as macOS 27.2 where available; a green CI build
   does not replace direct runtime testing on both systems.

CI verifies compilation and focused logic, but does **not** provide a live
Finder, real CBR book, or macOS 14 runtime test.
