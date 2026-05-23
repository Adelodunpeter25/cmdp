#!/bin/bash
set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"

echo "Starting cmdp Development Environment..."

# 1. Build Go Daemon
echo "Building Go Daemon..."
cd "$PROJECT_ROOT/daemon"
make lib

# 2. Build Swift App
echo "Building Swift App (cmdp)..."
cd "$PROJECT_ROOT/cmdp"
swift build

APP_NAME="cmdp-dev"
BUNDLE_ID="com.Adelodunpeter25.cmdp.dev"
BUNDLE_PATH="${APP_NAME}.app"

echo "📦 Creating Dev Bundle..."
rm -rf "${BUNDLE_PATH}"
mkdir -p "${BUNDLE_PATH}/Contents/MacOS"
mkdir -p "${BUNDLE_PATH}/Contents/Resources"
mkdir -p "${BUNDLE_PATH}/Contents/Frameworks"

# Copy the binary
cp .build/debug/cmdp "${BUNDLE_PATH}/Contents/MacOS/"

# Copy Sparkle framework
SPARKLE_FRAMEWORK="$(find .build -name "Sparkle.framework" -type d | head -n 1)"
if [[ -n "$SPARKLE_FRAMEWORK" ]]; then
    cp -R "$SPARKLE_FRAMEWORK" "${BUNDLE_PATH}/Contents/Frameworks/"
    echo "📦 Embedded Sparkle.framework"
else
    echo "⚠️  Sparkle.framework not found!"
fi

# Generate Dev Info.plist
cat <<PLIST > "${BUNDLE_PATH}/Contents/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>cmdp</string>
    <key>CFBundleIdentifier</key>
    <string>${BUNDLE_ID}</string>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0-dev</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSAppleEventsUsageDescription</key>
    <string>cmdp needs to control System Events to perform actions like Sleep, Restart, and Shut Down.</string>
</dict>
</plist>
PLIST

# 3. Ad-hoc sign the bundle
echo "✍️  Ad-hoc signing dev bundle..."
codesign --force --deep --sign - "${BUNDLE_PATH}"

echo "🚀 Launching $APP_NAME..."
"./${BUNDLE_PATH}/Contents/MacOS/cmdp"
