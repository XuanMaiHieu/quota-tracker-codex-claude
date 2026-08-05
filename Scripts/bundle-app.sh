#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG="${1:-debug}"

# Each developer signs with their own local certificate (Keychain ACLs are
# per-machine anyway), configured via .env — see .env.example. .env is
# gitignored so nobody's identity name ends up in the shared repo.
if [[ -f "$ROOT_DIR/.env" ]]; then
    set -a
    source "$ROOT_DIR/.env"
    set +a
fi

# Stable local signing identity (see Keychain Access > Certificate Assistant >
# Create a Certificate > Code Signing). Signing with the same identity on
# every build keeps the app's designated requirement stable, so macOS
# Keychain ACLs (e.g. "Always Allow" for reading Claude Code's OAuth token)
# persist across rebuilds instead of re-prompting every time.
SIGN_IDENTITY="${CODEXMETER_SIGN_IDENTITY:-CodexMeter Local Signing}"

if [[ "$CONFIG" == "release" ]]; then
    swift build -c release --package-path "$ROOT_DIR"
    BIN_PATH="$ROOT_DIR/.build/release/CodexMeter"
else
    swift build --package-path "$ROOT_DIR"
    BIN_PATH="$ROOT_DIR/.build/debug/CodexMeter"
fi

APP_DIR="$ROOT_DIR/.build/CodexMeter.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

echo "Signing with identity: $SIGN_IDENTITY"
# Sign the raw binary before it's placed inside the .app bundle. Signing it
# in-place under Contents/MacOS makes codesign treat it as part of a bundle
# and refuse ("unsealed contents present in the bundle root") because the
# resource bundle below sits loose at the .app root, outside Contents/.
# Signing the standalone Mach-O first avoids that bundle-aware check
# entirely; the embedded signature survives the plain file copy.
codesign --force --sign "$SIGN_IDENTITY" "$BIN_PATH"
codesign --verify --verbose "$BIN_PATH"

cp "$BIN_PATH" "$MACOS_DIR/CodexMeter"

# SPM's generated Bundle.module accessor looks for this bundle directly under
# Bundle.main.bundleURL (the .app root), not Contents/Resources.
RESOURCE_BUNDLE="$(dirname "$BIN_PATH")/CodexMeter_CodexMeter.bundle"
if [[ -d "$RESOURCE_BUNDLE" ]]; then
    cp -R "$RESOURCE_BUNDLE" "$APP_DIR/CodexMeter_CodexMeter.bundle"
fi

cat > "$CONTENTS_DIR/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>CodexMeter</string>
    <key>CFBundleIdentifier</key>
    <string>dev.hieumike.codexmeter</string>
    <key>CFBundleName</key>
    <string>Codex Meter</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>0.1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
PLIST

echo "Bundled: $APP_DIR"
