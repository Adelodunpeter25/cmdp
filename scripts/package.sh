#!/bin/bash
set -e

# Configuration
APP_NAME="cmdp"
BUNDLE_ID="com.Adelodunpeter25.cmdp"

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"

echo "🚀 Starting production build for $APP_NAME..."

# 1. Build Go Daemon
echo "Building Go Daemon..."
cd "$PROJECT_ROOT/daemon"
# Assuming we want a release build of the Go lib too (optimizations)
go build -buildmode=c-archive -o build/libsearch.a ./pkg/bridge

# 2. Build Swift App (Release)
echo "Building Swift App (cmdp)..."
cd "$PROJECT_ROOT/cmdp"
swift build -c release

# 3. Assembling the bundle
echo "📦 Assembling .app bundle..."
rm -rf "${APP_NAME}.app"
mkdir -p "${APP_NAME}.app/Contents/MacOS"
mkdir -p "${APP_NAME}.app/Contents/Resources"

# 4. Copy binaries
cp .build/release/cmdp "${APP_NAME}.app/Contents/MacOS/"

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
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
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

# 6. Ad-hoc sign the bundle
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
