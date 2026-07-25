#!/bin/zsh
# Recovers from the stale-signed-UI-runner failure mode: the macOS UI suite
# fails wholesale (element queries time out even on known-good code) because
# the XCUITest runner app in DerivedData no longer has a valid signature the
# system's automation permission recognizes. A full rebuild from clean
# DerivedData restores it. See README "Build and test".
#
# Usage: scripts/reset-ui-tests.sh
set -euo pipefail

cd "$(dirname "$0")/.."

echo "Killing any leftover app/runner processes..."
pkill -f "BookmarkCollections.app/Contents/MacOS/BookmarkCollections" 2>/dev/null || true
pkill -f "BookmarkCollectionsUITests-Runner" 2>/dev/null || true

echo "Removing project DerivedData..."
# (N) null-glob: don't abort when DerivedData is already gone
rm -rf ~/Library/Developer/Xcode/DerivedData/BookmarkCollections-*(N)

echo "Rebuilding and running the macOS UI suite..."
xcodebuild test \
  -project BookmarkCollections.xcodeproj \
  -scheme BookmarkCollections \
  -destination 'platform=macOS' \
  -only-testing:BookmarkCollectionsUITests
