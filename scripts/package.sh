#!/bin/bash
set -e

# Configuration
APP_NAME="cmdp"
BUNDLE_ID="com.Adelodunpeter25.cmdp"
APP_VERSION="${CMDP_VERSION:-1.0.1}"
BUILD_NUMBER="${CMDP_BUILD_NUMBER:-1}"

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"

# Target architecture argument (optional): "x86_64" or "arm64" (aliases: x64, amd64)
TARGET_ARCH="${1:-}"

if [[ -z "$TARGET_ARCH" ]]; then
    HOST_ARCH="$(uname -m)"
    if [[ "$HOST_ARCH" == "arm64" ]]; then
        TARGET_ARCH="arm64"
    else
        TARGET_ARCH="x86_64"
    fi
fi

if [[ "$TARGET_ARCH" == "x64" || "$TARGET_ARCH" == "amd64" ]]; then
    TARGET_ARCH="x86_64"
fi

echo "🚀 Starting production build for $APP_NAME ($TARGET_ARCH)..."

# 1. Build Go Daemon
echo "Building Go Daemon..."
cd "$PROJECT_ROOT/daemon"
SDK_PATH="$(xcrun --show-sdk-path)"
if [[ "$TARGET_ARCH" == "x86_64" ]]; then
    CGO_ENABLED=1 GOOS=darwin GOARCH=amd64 CC="clang -arch x86_64 -isysroot $SDK_PATH" go build -buildmode=c-archive -o build/libsearch.a ./pkg/bridge
else
    CGO_ENABLED=1 GOOS=darwin GOARCH=arm64 CC="clang -arch arm64 -isysroot $SDK_PATH" go build -buildmode=c-archive -o build/libsearch.a ./pkg/bridge
fi

echo "Go search library built at daemon/build/libsearch.a."

# 2. Build Swift App (Release)
echo "Building Swift App (cmdp)..."
cd "$PROJECT_ROOT/cmdp"
swift build -c release --arch "$TARGET_ARCH"

# 3. Assembling the bundle
echo "📦 Assembling .app bundle..."
rm -rf "${APP_NAME}.app"
mkdir -p "${APP_NAME}.app/Contents/MacOS"
mkdir -p "${APP_NAME}.app/Contents/Resources"
mkdir -p "${APP_NAME}.app/Contents/Frameworks"

# 4. Copy binaries
BINARY_PATH=".build/${TARGET_ARCH}-apple-macosx/release/cmdp"
if [[ ! -f "$BINARY_PATH" ]]; then
    # Fallback to default path if arch-specific directory doesn't exist
    BINARY_PATH=".build/release/cmdp"
fi
cp "$BINARY_PATH" "${APP_NAME}.app/Contents/MacOS/"

# Add RPATH to find Sparkle.framework inside Contents/Frameworks
install_name_tool -add_rpath "@loader_path/../Frameworks" "${APP_NAME}.app/Contents/MacOS/cmdp"


# Copy Sparkle framework
SPARKLE_FRAMEWORK="$(find .build -name "Sparkle.framework" -type d | head -n 1)"
if [[ -n "$SPARKLE_FRAMEWORK" ]]; then
    cp -R "$SPARKLE_FRAMEWORK" "${APP_NAME}.app/Contents/Frameworks/"
    echo "📦 Embedded Sparkle.framework"
else
    echo "⚠️  Sparkle.framework not found!"
fi

# 5. Generate Info.plist
cat <<PLIST > "${APP_NAME}.app/Contents/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>${APP_NAME}</string>
    <key>CFBundleIdentifier</key>
    <string>${BUNDLE_ID}</string>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>${APP_VERSION}</string>
    <key>CFBundleVersion</key>
    <string>${BUILD_NUMBER}</string>
    <key>SUFeedURL</key>
    <string>https://raw.githubusercontent.com/Adelodunpeter25/cmdp/main/appcast-x64.xml</string>
    <key>SUPublicEDKey</key>
    <string>APWKwPLf5U6sLRsYxxuUCrhCYVwtEl4ihDl1XJUNylI=</string>
    <key>SUScheduledCheckInterval</key>
    <integer>43200</integer>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSAppleEventsUsageDescription</key>
    <string>cmdp needs to control System Events to perform actions like Sleep, Restart, and Shut Down.</string>
</dict>
</plist>
PLIST

# 6. Copy app icon
ICNS_SRC="$PROJECT_ROOT/cmdp/Resources/AppIcon.icns"
if [[ -f "$ICNS_SRC" ]]; then
    cp "$ICNS_SRC" "${APP_NAME}.app/Contents/Resources/AppIcon.icns"
    echo "🎨 App icon copied."
else
    echo "⚠️  AppIcon.icns not found at $ICNS_SRC — run scripts/make_icns.sh first."
fi

# 7. Ad-hoc sign the bundle
echo "✍️  Ad-hoc signing the bundle..."
codesign --force --deep --sign - "${APP_NAME}.app"

# 7. Create DMG
echo "💿 Creating .dmg installer..."
rm -f "${APP_NAME}.dmg"
mkdir -p dmg_folder
cp -R "${APP_NAME}.app" dmg_folder/
ln -s /Applications dmg_folder/Applications
hdiutil create -volname "${APP_NAME}" -srcfolder dmg_folder -ov -format UDZO "${APP_NAME}.dmg" > /dev/null
rm -rf dmg_folder

echo "✅ Success! ${APP_NAME}.app and ${APP_NAME}.dmg are ready in the project root."
