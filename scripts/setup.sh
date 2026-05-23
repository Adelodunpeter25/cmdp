#!/bin/bash
set -e

echo "Setting up cmdp project..."

# 1. Initialize Go daemon
echo "Initializing Go daemon..."
cd daemon
go mod tidy
make lib

# 2. Initialize Swift app
echo "Initializing Swift app..."
cd ../cmdp
swift build

# 3. Check for Sparkle signing keys
echo "Checking for Sparkle signing keys..."
# Check if generate_keys exists in checkouts
GENERATE_KEYS_TOOL=$(find .build -name "generate_keys" -type f | head -n 1)

if [[ -n "$GENERATE_KEYS_TOOL" ]]; then
    echo "Sparkle tools found."
    # We can't easily check for the private key in the keychain via script without prompts,
    # but we can remind the user.
    echo "Note: Ensure you have generated your EdDSA keys for autoupdates."
    echo "If you haven't, run: $GENERATE_KEYS_TOOL"
else
    echo "⚠️  Sparkle tools not found yet. They will be available after the first successful Swift build."
fi

echo "Setup complete! Run ./scripts/dev.sh to start the app."
