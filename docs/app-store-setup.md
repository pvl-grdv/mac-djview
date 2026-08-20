# App Store / signed distribution setup

This document describes future signed distribution. The current GitHub build is ad-hoc signed and not notarized.

## Before starting

1. Enroll in the Apple Developer Program if Developer ID notarization or App Store distribution is required.
2. Add the Apple ID/team in Xcode Settings → Accounts.
3. Decide the permanent production bundle identifier before publishing through App Store Connect.

The current bundle script uses:

`com.mac-djview.MacDjView`

Changing the bundle identifier is acceptable for this independent downstream before a signed production identity is established. Once an App Store product is created, treat its identifier as permanent.

## Current app assets and platform settings

- macOS deployment target: 14.0.
- iOS/iPadOS deployment target: 17.0.
- macOS release architecture: arm64 only.
- App icon source: `Resources/AppIcon.icon` (Icon Composer), not a standalone 1024×1024 PNG.
- Privacy manifest: `Sources/MacDjView/PrivacyInfo.xcprivacy`.
- Sandbox entitlements: `MacDjView.entitlements`.
- DjVu UTI: `org.djvu.djvu`.

The bundle script compiles the Icon Composer source with `actool`, creates `Assets.car` plus `AppIcon.icns`, generates `Info.plist`, and ad-hoc signs the app.

## Xcode project strategy

The codebase is SwiftPM-first. Opening `Package.swift` in Xcode is sufficient for development and device builds.

For App Store/archive-specific configuration, a thin Xcode app wrapper may be more practical than forcing distribution metadata into the executable SwiftPM target. If a wrapper project is introduced, keep the DjVu decoder/search code in the package and keep signing/extension targets in the Xcode project.

This will also be the natural place for future macOS targets such as Quick Look/thumbnail extensions and any Spotlight plug-in packaging that cannot be expressed cleanly in the current SwiftPM-only bundle script.

## Required capabilities

For the main viewer:

- App Sandbox.
- User Selected File: Read Only.
- Hardened Runtime / appropriate signing for Developer ID or App Store distribution.

Do not add network entitlements unless a real product feature requires them.

Future Spotlight/Quick Look components should use the same `org.djvu.djvu` type declaration and tighter resource limits than the main app.

## Document type

Use the existing imported type declaration:

| Field | Value |
|---|---|
| Type | DjVu Document |
| Identifier | `org.djvu.djvu` |
| Conforms to | `public.data` |
| Extensions | `djvu`, `djv` |
| MIME | `image/vnd.djvu` |
| App role | Viewer |

## App Store Connect

When ready:

1. Create/register the permanent Bundle ID.
2. Create the macOS app record in App Store Connect.
3. Add description, category, screenshots, privacy information, and support/privacy URLs.
4. Archive with the distribution wrapper/project and upload through Xcode Organizer.
5. Provide Apple review with a safe sample DjVu document or clear reproduction instructions.

Do not claim Quick Look, Spotlight content indexing, OCR, or other roadmap features in store metadata until they are present in the submitted build.

## Developer ID distribution outside the App Store

A paid developer account also enables a better GitHub/direct-download path:

1. Sign with Developer ID Application.
2. Enable Hardened Runtime with the required sandbox entitlements.
3. Submit the app/archive for notarization.
4. Staple the notarization ticket.
5. Verify Gatekeeper with `spctl` before publishing.

Until then, direct GitHub builds remain ad-hoc signed and users should verify checksums/signatures before overriding Gatekeeper.

## Licensing note

Signing/distribution and copyright licensing are separate issues. The inherited upstream code currently has no declared LICENSE file. Resolve that provenance/licensing question before relying on an App Store or other public distribution plan that assumes a particular project-wide license.
