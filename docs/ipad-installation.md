# Install on an iPad with a free Apple Account

MacDjView supports **iPadOS 17+**, including the **10.5-inch iPad Pro (2017)**, which cannot install iPadOS 18. Xcode 27 supports development and debugging on devices running iPadOS 17. A paid Apple Developer Program membership is **not** needed to run a development build on your own iPad.

## What you need

- An Apple silicon Mac running a version compatible with Xcode 27 (macOS 27.2 works).
- Full Xcode 27 installed (not only Command Line Tools).
- The iPad and a working USB/Lightning cable, unlocked and trusted.
- A **free Apple Account** in Xcode; no App Store Connect or TestFlight account.

## Install

1. Clone/download the repository. Open **`ios/MacDjView-iOS.xcodeproj`** in Xcode (not just `Package.swift`).
2. In **Xcode → Settings → Accounts**, sign in with your Apple Account. Xcode displays a **Personal Team** if you're not enrolled in the paid program.
3. In the project editor select target **MacDjView-iPad → Signing & Capabilities**. Enable **Automatically manage signing** and select your **Personal Team**. If Xcode reports a bundle-ID collision, change **Bundle Identifier** to a unique reverse-DNS identifier (for example, `com.yourname.macdjview`). Do not commit your personal Team ID or private signing material.
4. Connect and unlock the iPad; tap **Trust** on its dialog and choose it as the destination in Xcode. If prompted, enable **Settings → Privacy & Security → Developer Mode** on the iPad and restart it.
5. Select the **MacDjView-iPad** scheme and press **⌘R**. Xcode builds, signs and installs the iPad app locally.
6. Copy the book into the iPad's **Files** app (On My iPad or iCloud Drive). Tap the reader's folder button to pick a `.cbr` or `.djvu` file.

Only Xcode performs signing. The GitHub CI build is deliberately unsigned; do not attempt to install its unsigned build directly.

## Free account limitations

Apple's Personal Team provisions a device build for **seven days**. When the app stops launching after expiration, connect the iPad and use **⌘R** again in Xcode to renew the provisioning. This is a limitation of free signing, not a bug in MacDjView. TestFlight, App Store distribution, Developer ID notarization, and creating distributable signed IPAs are outside this workflow. You don't need to buy a membership just to read your own CBR books.

## First-device checklist

- Open a local `.cbr` (RAR/RAR5) book; verify pages `1, 2, 10` appear in the correct order.
- Turn the iPad between portrait and landscape; try previous/next, zoom, and continuous paging.
- Reopen the same book and verify the last-read page is restored.
- Test a DjVu book so the existing renderer and text search still work.
- For malformed, encrypted or multi-volume RAR books, expect a clear error rather than an app crash.

CI builds the iPadOS arm64 `.app` with `CODE_SIGNING_ALLOWED=NO` and checks the deployment floor. **CI cannot verify actual iPadOS 17 runtime behavior** without a physical device running it.

## Troubleshooting

- **No Personal Team / provisioning error:** confirm the Apple Account is added in Xcode and Automatic Signing is enabled for **MacDjView-iPad**.
- **Device not shown:** unlock, trust the Mac, connect via USB, wait for Xcode's device setup; confirm Developer Mode.
- **Bundle ID unavailable:** choose a unique identifier in the target's Signing settings.
- **After 7 days app won't launch:** reconnect and press Run in Xcode to re-sign and install.
- **Only a command-line executable appears:** you probably opened `Package.swift`; open the **`ios/MacDjView-iOS.xcodeproj`** project.

## Official references

- [Apple Developer — Free account / Personal Team limits](https://developer.apple.com/help/account/basics/about-your-developer-account)
- [Apple — iPadOS 17 on 10.5-inch iPad Pro](https://www.apple.com/newsroom/2023/09/ipados-17-is-now-available/)
- [Apple — Xcode 27 deployment and device support](https://developer.apple.com/xcode/system-requirements)
- [Apple — Run an app on a device](https://help.apple.com/xcode/mac/current/en.lproj/dev5a825a1ca.html)
