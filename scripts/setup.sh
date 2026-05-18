#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
FORK_REPO="muxy-app/ghostty"
XCFRAMEWORK_DIR="$PROJECT_ROOT/GhosttyKit.xcframework"
RESOURCES_DIR="$PROJECT_ROOT/Sources/cmux/Resources"

if [[ -d "$XCFRAMEWORK_DIR" && -d "$RESOURCES_DIR/ghostty" ]]; then
    echo "==> GhosttyKit.xcframework and resources already present, skipping download"
    echo "    To re-download, remove: rm -rf GhosttyKit.xcframework Sources/cmux/Resources/ghostty Sources/cmux/Resources/shell-integration"
    exit 0
fi

echo "==> Fetching latest GhosttyKit release from $FORK_REPO"
LATEST_TAG=$(curl -fsSL "https://api.github.com/repos/$FORK_REPO/releases/latest" | grep '"tag_name"' | sed -E 's/.*"([^"]+)".*/\1/')
if [[ -z "$LATEST_TAG" ]]; then
    echo "Error: No releases found on $FORK_REPO"
    exit 1
fi
echo "    Tag: $LATEST_TAG"

cd "$PROJECT_ROOT"

if [[ ! -d "$XCFRAMEWORK_DIR" ]]; then
    echo "==> Downloading GhosttyKit.xcframework"
    curl -fsSL "https://github.com/$FORK_REPO/releases/download/$LATEST_TAG/GhosttyKit.xcframework.tar.gz" -o GhosttyKit.xcframework.tar.gz
    tar xzf GhosttyKit.xcframework.tar.gz
    rm GhosttyKit.xcframework.tar.gz

    echo "==> Syncing ghostty.h from xcframework"
    cp "$XCFRAMEWORK_DIR/macos-arm64_x86_64/Headers/ghostty.h" "$PROJECT_ROOT/Sources/GhosttyKit/ghostty.h"
fi

if [[ ! -d "$RESOURCES_DIR/ghostty" ]]; then
    echo "==> Downloading GhosttyKit runtime resources"
    curl -fsSL "https://github.com/$FORK_REPO/releases/download/$LATEST_TAG/GhosttyKit-resources.tar.gz" -o GhosttyKit-resources.tar.gz
    mkdir -p "$RESOURCES_DIR"
    tar xzf GhosttyKit-resources.tar.gz -C "$RESOURCES_DIR"
    cp -r "$RESOURCES_DIR/ghostty/shell-integration" "$RESOURCES_DIR/"
    rm GhosttyKit-resources.tar.gz
fi

echo "==> Done"
echo "    Run 'swift build' to build the project"
