#!/bin/bash
#
# Builds Ice with an ad-hoc signature and installs it to /Applications, for a
# machine with no Apple Developer team.
#
# Hardened runtime is turned off: with it on, library validation refuses to load
# the embedded Sparkle.framework into an ad-hoc signed process ("mapping process
# and mapped file (non-platform) have different Team IDs"). It only matters for
# notarized distribution.
#
# Sparkle auto-update is switched off so the official (macOS 27-broken) build
# cannot replace this one. An ad-hoc signature changes on every build, so
# Accessibility and Screen Recording must be granted again after each install.
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEST="${DEST:-/Applications}"
DERIVED="${DERIVED:-/tmp/ice-build}"
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"

echo "==> Building"
xcodebuild -project "$ROOT/Ice.xcodeproj" -scheme Ice -configuration Release \
    -destination 'platform=macOS' -derivedDataPath "$DERIVED" \
    CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM= \
    PROVISIONING_PROFILE_SPECIFIER= ENABLE_HARDENED_RUNTIME=NO \
    build | tail -3

APP="$DERIVED/Build/Products/Release/Ice.app"
codesign --verify --deep --strict "$APP"

echo "==> Installing to $DEST"
osascript -e 'quit app "Ice"' >/dev/null 2>&1 || true
sleep 1
pkill -x Ice || true
rm -rf "${DEST:?}/Ice.app"
ditto "$APP" "$DEST/Ice.app"
codesign --verify --deep --strict "$DEST/Ice.app"

defaults write com.jordanbaird.Ice SUAutomaticallyUpdate -bool false
defaults write com.jordanbaird.Ice SUEnableAutomaticChecks -bool false
tccutil reset Accessibility com.jordanbaird.Ice >/dev/null 2>&1 || true
tccutil reset ScreenCapture com.jordanbaird.Ice >/dev/null 2>&1 || true

open "$DEST/Ice.app"
echo "==> Running $DEST/Ice.app — grant Accessibility (and Screen Recording) when asked"
