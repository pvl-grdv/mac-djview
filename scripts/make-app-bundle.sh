#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.."

ENTITLEMENTS="MacDjView.entitlements"
PRIVACY_MANIFEST="Sources/MacDjView/PrivacyInfo.xcprivacy"
APP_BUNDLE="MacDjView.app"
APP_DIR="$APP_BUNDLE/Contents"
VERSION="${MACDJVIEW_VERSION:-1.0.0}"
VERSION="${VERSION#v}"
BUILD_NUMBER="${MACDJVIEW_BUILD_NUMBER:-1}"

if [[ ! "$VERSION" =~ ^[0-9]+(\.[0-9]+){1,2}$ ]]; then
    echo "Invalid app version '$VERSION'. Expected e.g. 1.0 or 1.0.0." >&2
    exit 1
fi

if [[ ! "$BUILD_NUMBER" =~ ^[0-9]+$ ]]; then
    echo "Invalid build number '$BUILD_NUMBER'. Expected an integer." >&2
    exit 1
fi

if [[ ! -f "$ENTITLEMENTS" ]]; then
    echo "Missing entitlements file: $ENTITLEMENTS" >&2
    exit 1
fi

if [[ ! -f "$PRIVACY_MANIFEST" ]]; then
    echo "Missing privacy manifest: $PRIVACY_MANIFEST" >&2
    exit 1
fi

echo "Building MacDjView $VERSION for arm64 / macOS 26+..."
swift build -c release --arch arm64 "$@"
BIN_DIR="$(swift build -c release --arch arm64 --show-bin-path "$@")"

rm -rf "$APP_BUNDLE"
mkdir -p "$APP_DIR/MacOS"
mkdir -p "$APP_DIR/Resources"

cp "$BIN_DIR/MacDjView" "$APP_DIR/MacOS/MacDjView"
strip "$APP_DIR/MacOS/MacDjView"
cp "$PRIVACY_MANIFEST" "$APP_DIR/Resources/PrivacyInfo.xcprivacy"

cat > "$APP_DIR/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>MacDjView</string>
    <key>CFBundleIdentifier</key>
    <string>com.mac-djview.MacDjView</string>
    <key>CFBundleName</key>
    <string>MacDjView</string>
    <key>CFBundleDisplayName</key>
    <string>MacDjView</string>
    <key>CFBundleVersion</key>
    <string>$BUILD_NUMBER</string>
    <key>CFBundleShortVersionString</key>
    <string>$VERSION</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSMinimumSystemVersion</key>
    <string>26.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
    <key>CFBundleDocumentTypes</key>
    <array>
        <dict>
            <key>CFBundleTypeName</key>
            <string>DjVu Document</string>
            <key>CFBundleTypeRole</key>
            <string>Viewer</string>
            <key>LSItemContentTypes</key>
            <array>
                <string>org.djvu.djvu</string>
            </array>
            <key>CFBundleTypeExtensions</key>
            <array>
                <string>djvu</string>
                <string>djv</string>
            </array>
        </dict>
    </array>
</dict>
</plist>
PLIST

plutil -lint "$APP_DIR/Info.plist"

# Ad-hoc signing is sufficient for local/testing builds and preserves the
# restrictive App Sandbox entitlements. A public notarized distribution would
# require a Developer ID certificate and Apple notarization credentials.
codesign --force --sign - --options runtime --entitlements "$ENTITLEMENTS" "$APP_BUNDLE"
codesign --verify --strict --verbose=2 "$APP_BUNDLE"

ARCHS="$(lipo -archs "$APP_DIR/MacOS/MacDjView")"
if [[ "$ARCHS" != "arm64" ]]; then
    echo "Unexpected architectures: $ARCHS" >&2
    exit 1
fi

if ! vtool -show-build "$APP_DIR/MacOS/MacDjView" | grep -Eq 'minos[[:space:]]+26\.0'; then
    echo "Binary does not declare macOS 26.0 as its minimum OS." >&2
    vtool -show-build "$APP_DIR/MacOS/MacDjView" >&2
    exit 1
fi

echo "Created and signed $APP_BUNDLE ($ARCHS, macOS 26+)"
