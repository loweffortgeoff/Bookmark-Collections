#!/bin/bash
# Builds Tucked (BookmarkCollections) for macOS and installs it to /Applications.
#
# The Mac needs a real install step, not just a build. Launching the build
# product in place leaves the only copy inside build/DerivedData, where the
# next rebuild, `xcodebuild test -destination 'platform=macOS'`, or
# scripts/reset-ui-tests.sh deletes or replaces it — so the app stops running
# and there is nothing left for Spotlight to find. Installing to /Applications
# gives the app a home that survives a build.
#
# Defaults to Debug so CloudKit stays on the Development environment, matching
# the iPhone and iPad installs. Set CONFIGURATION=Release once the Production
# CloudKit schema is deployed.

set -uo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR"

PROJECT="BookmarkCollections.xcodeproj"
SCHEME="BookmarkCollections"
APP_NAME="Tucked"
BUNDLE_ID="com.loweffortapps.BookmarkCollections"
CONFIGURATION="${CONFIGURATION:-Debug}"
DERIVED_DATA_PATH="build/DerivedData"

# Installed as Tucked.app. Finder and Spotlight
# match apps on the bundle's file name, not CFBundleDisplayName — installing
# under the build product's name means searching "Tucked" finds nothing.
INSTALL_PATH="/Applications/$APP_NAME.app"

LSREGISTER=/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister

echo "== Building macOS ($CONFIGURATION) =="
if ! xcodebuild build \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -configuration "$CONFIGURATION" \
    -destination 'platform=macOS' \
    -derivedDataPath "$DERIVED_DATA_PATH"; then
  echo "build failed"
  exit 1
fi

BUILT_APP="$DERIVED_DATA_PATH/Build/Products/$CONFIGURATION/$APP_NAME.app"
if [ ! -d "$BUILT_APP" ]; then
  echo "build succeeded but $BUILT_APP is missing"
  exit 1
fi

echo "== Quitting any running copy =="
osascript -e "tell application id \"$BUNDLE_ID\" to quit" 2>/dev/null
pkill -f "^$INSTALL_PATH/Contents/MacOS/$APP_NAME$" 2>/dev/null

echo "== Installing to $INSTALL_PATH =="
rm -rf "$INSTALL_PATH"
if ! ditto "$BUILT_APP" "$INSTALL_PATH"; then
  echo "install failed"
  exit 1
fi

# LaunchServices accumulates a registration per build directory the app has
# ever run from. Those paths are gone, but the records stay and keep Spotlight
# offering dead entries under stale display names. Drop them, then register
# the copy that actually exists.
echo "== Refreshing LaunchServices =="
"$LSREGISTER" -dump 2>/dev/null \
  | grep -E "^[[:space:]]*path:.*($SCHEME|$APP_NAME).*\.app " \
  | sed -E 's/^[[:space:]]*path:[[:space:]]*(.*) \(0x[0-9a-f]+\)$/\1/' \
  | sort -u \
  | while IFS= read -r stale; do
      [ -e "$stale" ] || "$LSREGISTER" -u "$stale" 2>/dev/null
    done
"$LSREGISTER" -f -R "$INSTALL_PATH"

echo "== Launching =="
if ! open "$INSTALL_PATH"; then
  echo "installed ok, launch failed"
  exit 1
fi

echo "Installed and launched $INSTALL_PATH"
