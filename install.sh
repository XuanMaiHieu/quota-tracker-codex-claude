#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_NAME="CodexMeter.app"
INSTALL_DIR="/Applications"

"$ROOT_DIR/Scripts/bundle-app.sh" release

echo "Installing to $INSTALL_DIR/$APP_NAME ..."
rm -rf "$INSTALL_DIR/$APP_NAME"
cp -R "$ROOT_DIR/.build/$APP_NAME" "$INSTALL_DIR/$APP_NAME"

# Restart the app if it's already running (e.g. re-install after an update).
pkill -f "$INSTALL_DIR/$APP_NAME/Contents/MacOS/CodexMeter" 2>/dev/null || true

open "$INSTALL_DIR/$APP_NAME"

echo "Done. Codex Meter is installed at $INSTALL_DIR/$APP_NAME and running in your menu bar."
