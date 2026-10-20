# Platform compatibility and WWDC decisions

MacDjView stays deliberately small: an offline reader, one shared Swift codebase, no backend, and no custom Glass, Metal, or document storage framework.

| Platform | Runtime floor | CI toolchain | Distribution |
| --- | --- | --- | --- |
| macOS Apple silicon | macOS 14 | Xcode 27 | Ad-hoc signed `.app.zip` with Gatekeeper instructions |
| iPad / iPhone arm64 | iPadOS/iOS 17 | Xcode 27 in GitHub Actions | Unsigned IPA artifact + local Sideloadly/AltStore signing; Xcode Personal Team is optional (7-day refresh) |

The **10.5-inch iPad Pro** supports iPadOS 17, but not 18. Xcode 27 supports debugging devices running iOS/iPadOS 17. Do **not** raise `IPHONEOS_DEPLOYMENT_TARGET` for UI features; new APIs require version checks and a fallback.

## WWDC 2024: foundations first

- [What's new in SwiftUI (WWDC24)](https://developer.apple.com/videos/play/wwdc2024/10144/) — native navigation, adaptive layouts, scrolling and platform support. The app uses `NavigationStack` on iPad, `@Observable` UI state, and `ScrollViewReader` with iPadOS 17 compatibility. No iOS 18-only tab redesign is needed for a one-document reader.
- [Meet Swift Testing (WWDC24)](https://developer.apple.com/videos/play/wwdc2024/10179/) — pure decoder and archive utilities stay covered by `swift test`. Keep SwiftPM as the test source of truth.

## WWDC 2025: use system chrome, measure before optimizing

- [Build a SwiftUI app with the new design (WWDC25)](https://developer.apple.com/videos/play/wwdc2025/323/) — native toolbars/menus/search automatically adapt to Liquid Glass on supported systems. Don't add custom glass or translucent layers over the comic pages.
- [What's new in SwiftUI (WWDC25)](https://developer.apple.com/videos/play/wwdc2025/256/) — use lazy scrolling, off-main-thread decoding and caching, and Instruments before introducing more complexity. Avoid eager extraction of large CBR archives.

## WWDC 2026: don't force OS 27-only features on older iPads

- [What's new in SwiftUI (WWDC26)](https://developer.apple.com/videos/play/wwdc2026/269/) — new `Document`/document-reader APIs and toolbar overflow are useful for newer systems but unavailable on iPadOS 17. Keep read-only `fileImporter` and the existing `PageDocument` adapter instead of migrating for fashion.
- Keep `@State` on view-owned `@Observable` instances; reserve `@MainActor` for view-driving state. Render and decompress off the main actor.
- Prefer system color, controls, menus, labels and accessibility. Add `#available` only when a new API solves a concrete need.

## CI + release flow (without paid membership)

1. Short topic branch → PR: macOS `swift test` + packaged app, iPadOS arm64 **`.app` target build**; check both macOS 14 and iPadOS 17 minimum deployment, DjVu/CBR registrations; upload an **unsigned IPA** so users can sideload without installing Xcode.
2. Merge after green CI and device smoke test. An automated iOS build is not a substitute for testing on the iPad Pro 10.5 itself.
3. Tags `vX.Y.Z` create only a macOS `.app.zip` release plus SHA-256. No Apple signing secrets or distribution certificates are needed or stored in GitHub.
4. On your own iPad, install the CI-produced IPA using Sideloadly or AltStore with a free Apple Account; alternatively use `ios/MacDjView-iOS.xcodeproj` with Personal Team in Xcode. See [the iPad installation guide](ipad-installation.md).

Avoid introducing Fastlane, Xcode Cloud, TestFlight, macOS notarization, CI signing secrets, new major Swift language modes, or an OS 27-only UI until they solve a real product problem.

## Runtime smoke test still required

Actual iPadOS 17 + 10.5-inch hardware, large RAR/RAR5 solid CBR books, memory pressure, and older ImageIO image formats need manual testing. The test suite and CI certify compilation and limited input safety, not end-to-end on-device compatibility.
