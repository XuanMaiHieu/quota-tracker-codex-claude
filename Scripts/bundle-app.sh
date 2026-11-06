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

cp "$BIN_PATH" "$MACOS_DIR/CodexMeter"

# Resources go under Contents/Resources so the whole .app can be sealed by
# codesign (anything loose at the .app root makes it refuse to sign).
# AppLogo looks them up via Bundle.main first.
RESOURCE_DIR_SRC="$(dirname "$BIN_PATH")/CodexMeter_CodexMeter.bundle/Resources"
if [[ -d "$RESOURCE_DIR_SRC" ]]; then
    cp -R "$RESOURCE_DIR_SRC/." "$RESOURCES_DIR/"
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
    <!-- server-agy-api (Antigravity quota) is usually plain http:// on an IP address, which
         App Transport Security blocks by default and per-IP exceptions are not supported. -->
    <key>NSAppTransportSecurity</key>
    <dict>
        <key>NSAllowsArbitraryLoads</key>
        <true/>
    </dict>
</dict>
</plist>
PLIST

# Sign the assembled bundle, not just the Mach-O. A binary signed on its own
# and then copied into a bundle fails verification as an app ("code has no
# resources but signature indicates they must be present"), so the Keychain
# can never match it against its "Always Allow" entry and keeps prompting.
echo "Signing with identity: $SIGN_IDENTITY"
codesign --force --sign "$SIGN_IDENTITY" "$APP_DIR"
codesign --verify --strict --verbose "$APP_DIR"

echo "Bundled: $APP_DIR"
