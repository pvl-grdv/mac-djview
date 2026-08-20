#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.."

ENTITLEMENTS="MacDjView.entitlements"
PRIVACY_MANIFEST="Sources/MacDjView/PrivacyInfo.xcprivacy"
APP_ICON="Resources/AppIcon.icon"
APP_ICON_NAME="AppIcon"
BUNDLE_ID="com.mac-djview.MacDjView"
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

if [[ ! -d "$APP_ICON" ]]; then
    echo "Missing Icon Composer source: $APP_ICON" >&2
    exit 1
fi

if ! xcrun --find actool >/dev/null 2>&1; then
    echo "actool is required to compile the Icon Composer source. Install/select full Xcode." >&2
    exit 1
fi

echo "Building MacDjView $VERSION for arm64 / macOS 14+..."
swift build -c release --arch arm64 "$@"
BIN_DIR="$(swift build -c release --arch arm64 --show-bin-path "$@")"

rm -rf "$APP_BUNDLE"
mkdir -p "$APP_DIR/MacOS"
mkdir -p "$APP_DIR/Resources"

cp "$BIN_DIR/MacDjView" "$APP_DIR/MacOS/MacDjView"
strip "$APP_DIR/MacOS/MacDjView"
cp "$PRIVACY_MANIFEST" "$APP_DIR/Resources/PrivacyInfo.xcprivacy"

# Compile the Icon Composer master into the native appearance-aware Assets.car
# plus an ICNS fallback for pre-Liquid-Glass macOS releases. Xcode/actool
# generates the fallback from the same source because our deployment target is 14.
ICON_TMP="$(mktemp -d)"
trap 'rm -rf "$ICON_TMP"' EXIT

xcrun actool "$APP_ICON" \
    --compile "$ICON_TMP" \
    --app-icon "$APP_ICON_NAME" \
    --include-all-app-icons \
    --enable-on-demand-resources NO \
    --development-region en \
    --target-device mac \
    --minimum-deployment-target 14.0 \
    --platform macosx \
    --bundle-identifier "$BUNDLE_ID" \
    --output-partial-info-plist "$ICON_TMP/partial-Info.plist" \
    --output-format human-readable-text \
    --notices --warnings --errors

test -f "$ICON_TMP/Assets.car"
test -f "$ICON_TMP/$APP_ICON_NAME.icns"
cp "$ICON_TMP/Assets.car" "$APP_DIR/Resources/Assets.car"
cp "$ICON_TMP/$APP_ICON_NAME.icns" "$APP_DIR/Resources/$APP_ICON_NAME.icns"

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
    <string>$BUNDLE_ID</string>
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
    <key>CFBundleIconName</key>
    <string>$APP_ICON_NAME</string>
    <key>CFBundleIconFile</key>
    <string>$APP_ICON_NAME</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
    <key>UTImportedTypeDeclarations</key>
    <array>
        <dict>
            <key>UTTypeIdentifier</key>
            <string>org.djvu.djvu</string>
            <key>UTTypeDescription</key>
            <string>DjVu Document</string>
            <key>UTTypeConformsTo</key>
            <array>
                <string>public.data</string>
            </array>
            <key>UTTypeTagSpecification</key>
            <dict>
                <key>public.filename-extension</key>
                <array>
                    <string>djvu</string>
                    <string>djv</string>
                </array>
                <key>public.mime-type</key>
                <string>image/vnd.djvu</string>
            </dict>
        </dict>
    </array>
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
test "$(plutil -extract CFBundleIconName raw "$APP_DIR/Info.plist")" = "$APP_ICON_NAME"
test "$(plutil -extract CFBundleIconFile raw "$APP_DIR/Info.plist")" = "$APP_ICON_NAME"
test "$(plutil -extract UTImportedTypeDeclarations.0.UTTypeIdentifier raw "$APP_DIR/Info.plist")" = "org.djvu.djvu"
test "$(/usr/libexec/PlistBuddy -c 'Print :UTImportedTypeDeclarations:0:UTTypeTagSpecification:public.mime-type' "$APP_DIR/Info.plist")" = "image/vnd.djvu"

# Ad-hoc signing is sufficient for local/testing builds and preserves the
# restrictive App Sandbox entitlements. Internet-downloaded builds will not
# pass Gatekeeper notarization checks without a paid Developer ID identity.
codesign --force --sign - --options runtime --entitlements "$ENTITLEMENTS" "$APP_BUNDLE"
codesign --verify --strict --verbose=2 "$APP_BUNDLE"

ARCHS="$(lipo -archs "$APP_DIR/MacOS/MacDjView")"
if [[ "$ARCHS" != "arm64" ]]; then
    echo "Unexpected architectures: $ARCHS" >&2
    exit 1
fi

if ! vtool -show-build "$APP_DIR/MacOS/MacDjView" | grep -Eq 'minos[[:space:]]+14\.0'; then
    echo "Binary does not declare macOS 14.0 as its minimum OS." >&2
    vtool -show-build "$APP_DIR/MacOS/MacDjView" >&2
    exit 1
fi

echo "Created and signed $APP_BUNDLE ($ARCHS, macOS 14+, Icon Composer app icon)"
