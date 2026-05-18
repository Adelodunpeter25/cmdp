#!/bin/bash
set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$( cd "$SCRIPT_DIR/../.." && pwd )"

echo "Starting Development Environment..."

# 1. Build Go Search Daemons (cmuxd)
echo "Building Search Daemons (cmuxd)..."
cd "$PROJECT_ROOT/cmux-daemon"
./build.sh

# 2. Build and Bundle Swift App
echo "Building Swift App (cmux)..."
cd "$PROJECT_ROOT/cmux"
swift build

APP_NAME="cmux-dev"
BUNDLE_ID="com.cmux.app.dev"
BUNDLE_PATH="${APP_NAME}.app"

echo "📦 Creating Dev Bundle..."
rm -rf "${BUNDLE_PATH}"
mkdir -p "${BUNDLE_PATH}/Contents/MacOS"
mkdir -p "${BUNDLE_PATH}/Contents/Resources"

# Copy the debug binary
cp .build/debug/cmux "${BUNDLE_PATH}/Contents/MacOS/"

# Copy resources
cp -R Sources/cmux/Resources/* "${BUNDLE_PATH}/Contents/Resources/"

# Generate Dev Info.plist
cat <<PLIST > "${BUNDLE_PATH}/Contents/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>cmux</string>
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
</dict>
</plist>
PLIST

# 3. Ad-hoc sign the bundle (REQUIRED for notifications)
echo "✍️  Ad-hoc signing dev bundle..."
codesign --force --deep --sign - "${BUNDLE_PATH}"

echo "🚀 Launching $APP_NAME..."
# Run the binary directly from the bundle to keep logs in terminal
"./${BUNDLE_PATH}/Contents/MacOS/cmux"
