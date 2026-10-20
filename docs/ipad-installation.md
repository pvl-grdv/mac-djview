# Install on iPad Pro 10.5-inch without paid Apple Developer membership

MacDjView supports iPadOS 17+, including iPad Pro 10.5-inch (2017).
The app is built by GitHub Actions using Xcode; **you do not need Xcode installed on your own Mac** to install the CI build.

## Recommended: GitHub Actions + Sideloadly (no local Xcode)

1. Open the [GitHub Actions Build and release workflow](https://github.com/pvl-grdv/mac-djview/actions/workflows/build-macos-app.yml) and pick the latest **successful** run for the desired commit/branch.
2. Under **Artifacts**, download `MacDjView-iPadOS-unsigned-ipa`. Unzip GitHub's downloaded artifact ZIP; it contains `MacDjView-iPadOS-unsigned.ipa` and a SHA-256 checksum. **Do not extract the inner IPA.**
3. Download [Sideloadly for macOS](https://sideloadly.io/) from its official site. You do **not** need Xcode or a paid Apple Developer Program membership.
4. Connect the unlocked iPad to the Mac using Lightning and accept **Trust This Computer**. Select the iPad in Sideloadly, drag `MacDjView-iPadOS-unsigned.ipa` into Sideloadly, and use **Apple ID Sideload** with your free Apple Account. Sideloadly signs the IPA for your specific iPad and installs it.
5. On the iPad, trust the developer profile at **Settings → General → VPN & Device Management** if requested, and enable **Settings → Privacy & Security → Developer Mode** if prompted (restarting the iPad if required).
6. Open MacDjView, tap the folder button, and select your local `.cbr` or `.djvu` book from Files.

The IPA in Actions is **unsigned and cannot be installed directly**. The signing/installing step is done locally by Sideloadly, never by GitHub. This is a personal development install, not an App Store or TestFlight release.

### Keep the app available after 7 days

Apple's free provisioning profile expires **every seven days**, regardless of how the app was compiled. Sideloadly offers an automatic refresh daemon; it can re-sign/reinstall while the iPad is connected by USB or reachable over the same Wi-Fi network with the Mac running. Otherwise, sideload the same IPA again before it expires. Refresh is not guaranteed when the Mac is off or the iPad is away.

Keep the **same Apple Account and bundle identifier** for refresh/reinstallation to avoid losing app data. Keep the original CBR books safely stored in the iPad Files app, rather than relying on the application's sandbox for sole copies.

**Security:** Sideloadly is third-party software and asks for Apple Account authentication. Download from the official site and review its privacy/credential handling. If you'd rather not enter your primary Apple Account into a third-party tool, use a dedicated free Apple Account for personal sideloading, or choose the Xcode method below.

Alternative: [AltStore Classic](https://altstore.io/) and [AltServer for macOS](https://faq.altstore.io/altstore-classic/how-to-install-altstore-macos) can sign/install IPA files with a free Apple Account and attempt periodic refresh over Wi-Fi. On iPadOS 17 use **AltStore Classic**, not the region-restricted AltStore PAL.

## Alternative: install directly from Xcode

If you prefer Apple's own tooling, install full Xcode 27 on macOS 27.2.

1. Clone the repository and open **`ios/MacDjView-iOS.xcodeproj`** (not just `Package.swift`).
2. Add your free Apple Account under **Xcode → Settings → Accounts**.
3. Select **MacDjView-iPad → Signing & Capabilities**, enable **Automatically manage signing**, and choose your **Personal Team**. Change the bundle identifier locally if it collides with an existing App ID; do not commit your personal Team ID or signing material.
4. Connect/trust the iPad, select it as the run destination, enable Developer Mode when prompted, and press **⌘R** to build, sign and install.
5. Repeat with Xcode to renew a Personal Team installation after seven days.

## What the CI checks

GitHub Actions builds a real arm64 `MacDjView.app` for iPadOS with `CODE_SIGNING_ALLOWED=NO`, verifies `MinimumOSVersion = 17.0`, and tests both DjVu and CBR document type registrations. It then creates a standard `Payload/MacDjView.app` unsigned IPA and uploads it as an artifact. The workflow stores no Apple credentials or provisioning certificates. Artifacts are retained for **14 days**.

**A successful CI build does not prove the reader works on physical iPadOS 17 hardware.** Real CBR books, large archives, memory pressure and rotation still require on-device testing.

## First-device checklist

- Open a real RAR/RAR5 `.cbr` book and confirm pages `1`, `2`, `10` are sorted correctly.
- Check page navigation, rotation, zoom and continuous scrolling.
- Reopen the same book and check reading-position restoration.
- Open a `.djvu` book to check rendering and native text search.
- Confirm encrypted or multi-volume RAR files fail clearly rather than hanging or crashing.

## Troubleshooting

- **GitHub artifact expired or missing:** trigger another workflow run or use a more recent green run. The uploaded file is the outer artifact ZIP; extract that ZIP to get the `.ipa`.
- **No device found in Sideloadly:** reconnect over USB, unlock the iPad, trust the computer, and check Finder's device list.
- **Cannot launch app:** trust the Apple Account's developer profile and enable Developer Mode when required.
- **After 7 days it stops launching:** refresh using Sideloadly/AltStore, or reinstall via Xcode with the same signing identity.
- **IPA says invalid signature:** an unsigned CI IPA must be signed with Sideloadly or AltStore; do not use a generic file installer.
- **Sideload utility incompatible with your Mac:** use the Xcode fallback; no specific sideloader's compatibility with macOS 27.2 has been tested on your machine.

## Sources

- [Apple Developer — free account restrictions](https://developer.apple.com/help/account/basics/about-your-developer-account)
- [Sideloadly — Apple ID sideloading and automatic refresh](https://sideloadly.io/)
- [Sideloadly FAQ — refresh requirements](https://sideloadly.io/faq.html)
- [AltStore Classic and AltServer](https://faq.altstore.io/altstore-classic/how-to-install-altstore-macos)
- [iPadOS 17 and iPad Pro compatibility](https://www.apple.com/newsroom/2023/09/ipados-17-is-now-available/)
