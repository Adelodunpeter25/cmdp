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

echo "Setup complete! Run ./scripts/dev.sh to start the app."
