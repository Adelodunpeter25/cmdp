#!/usr/bin/env bash
# make_icns.sh
# Converts resources/logo.png → AppIcon.icns and copies it to cmdp/Resources/
#
# Tools used:
#   sips     — macOS built-in image processor (resize PNG)
#   iconutil — macOS built-in .iconset → .icns compiler
#
# Usage: run from the repo root OR from the scripts/ directory.
#   ./scripts/make_icns.sh

set -euo pipefail

# ── Resolve paths relative to the repo root ──────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

SRC_PNG="$REPO_ROOT/resources/logo.png"
ICONSET_DIR="$REPO_ROOT/resources/AppIcon.iconset"
ICNS_OUT="$REPO_ROOT/resources/AppIcon.icns"
DEST_DIR="$REPO_ROOT/cmdp/Resources"
DEST_ICNS="$DEST_DIR/AppIcon.icns"

# ── Sanity checks ─────────────────────────────────────────────────────────────
if [[ ! -f "$SRC_PNG" ]]; then
  echo "❌  Source not found: $SRC_PNG"
  exit 1
fi

for cmd in sips iconutil; do
  if ! command -v "$cmd" &>/dev/null; then
    echo "❌  Required tool not found: $cmd"
    exit 1
  fi
done

echo "📐  Source: $SRC_PNG"
echo "🔨  Building iconset..."

# ── Build the .iconset directory ──────────────────────────────────────────────
# macOS requires exactly these sizes inside an .iconset:
#   16, 32, 64, 128, 256, 512 — each at 1x and 2x (@2x)
rm -rf "$ICONSET_DIR"
mkdir -p "$ICONSET_DIR"

declare -A sizes=(
  ["icon_16x16.png"]=16
  ["icon_16x16@2x.png"]=32
  ["icon_32x32.png"]=32
  ["icon_32x32@2x.png"]=64
  ["icon_128x128.png"]=128
  ["icon_128x128@2x.png"]=256
  ["icon_256x256.png"]=256
  ["icon_256x256@2x.png"]=512
  ["icon_512x512.png"]=512
  ["icon_512x512@2x.png"]=1024
)

for filename in "${!sizes[@]}"; do
  px="${sizes[$filename]}"
  sips -z "$px" "$px" "$SRC_PNG" --out "$ICONSET_DIR/$filename" \
    --setProperty format png >/dev/null
done

echo "✅  Iconset built: $ICONSET_DIR"

# ── Compile .iconset → .icns ──────────────────────────────────────────────────
iconutil -c icns "$ICONSET_DIR" -o "$ICNS_OUT"
echo "✅  ICNS created: $ICNS_OUT"

# ── Copy to cmdp/Resources ────────────────────────────────────────────────────
mkdir -p "$DEST_DIR"
cp "$ICNS_OUT" "$DEST_ICNS"
echo "✅  Copied to:    $DEST_ICNS"

# ── Cleanup temp iconset ──────────────────────────────────────────────────────
rm -rf "$ICONSET_DIR"
echo ""
echo "🎉  Done! AppIcon.icns is ready at:"
echo "    $DEST_ICNS"
