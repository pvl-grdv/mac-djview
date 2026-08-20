#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.."

ENTITLEMENTS="MacDjView.entitlements"
APP_BUNDLE="MacDjView.app"
APP_DIR="$APP_BUNDLE/Contents"

if [[ ! -f "$ENTITLEMENTS" ]]; then
    echo "Missing entitlements file: $ENTITLEMENTS" >&2
    exit 1
fi

echo "Building MacDjView..."
swift build -c release "$@"
BIN_DIR="$(swift build -c release "$@" --show-bin-path)"

rm -rf "$APP_BUNDLE"
mkdir -p "$APP_DIR/MacOS"
mkdir -p "$APP_DIR/Resources"

# Copy binary and strip debug symbols.
cp "$BIN_DIR/MacDjView" "$APP_DIR/MacOS/"
strip "$APP_DIR/MacOS/MacDjView"

# Write Info.plist.
cat > "$APP_DIR/Info.plist" << 'PLIST'
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
    <string>1.0</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleSignature</key>
    <string>????</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
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

# Ad-hoc sign the app and apply the restrictive sandbox entitlements.
codesign --force --sign - --entitlements "$ENTITLEMENTS" "$APP_BUNDLE"

# Fail the build if the signature is invalid.
codesign --verify --strict --verbose=2 "$APP_BUNDLE"

echo "Created and signed $APP_BUNDLE"
echo "Run with: open $APP_BUNDLE"
