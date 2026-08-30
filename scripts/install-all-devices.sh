#!/bin/bash
# Builds and installs Tucked (BookmarkCollections) to the Mac, iPhone, and iPad
# used for the real-device CloudKit verification matrix
# (docs/verification/cloudkit-device-matrix.md).

# Unlock the iPhone and iPad before running this — devicectl cannot install
# or launch on a locked device.

set -uo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR"

PROJECT="BookmarkCollections.xcodeproj"
SCHEME="BookmarkCollections"
APP_NAME="Tucked"
BUNDLE_ID="com.loweffortapps.BookmarkCollections"
CONFIGURATION="${CONFIGURATION:-Debug}"
DERIVED_DATA_PATH="build/DerivedData"

IPHONE_NAME="Geoffrey's iPhone"
IPHONE_UDID="00008150-00066D092EF8401C"

IPAD_NAME="Geoffrey's iPad Pro"
IPAD_UDID="00008142-001471181E47801C"

MAC_STATUS="not run"
IPHONE_STATUS="not run"
IPAD_STATUS="not run"

echo "This will install to $IPHONE_NAME and $IPAD_NAME — make sure both are unlocked."
read -p "Press Enter to continue, or Ctrl+C to cancel... " _

echo "== Building and installing macOS =="
if scripts/install-mac.sh; then
  MAC_STATUS="installed and launched"
else
  MAC_STATUS="failed (see log above)"
fi

echo "== Building iOS (generic device) =="
if xcodebuild build \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -configuration "$CONFIGURATION" \
    -destination 'generic/platform=iOS' \
    -allowProvisioningUpdates \
    -derivedDataPath "$DERIVED_DATA_PATH"; then
  IOS_APP_PATH="$DERIVED_DATA_PATH/Build/Products/$CONFIGURATION-iphoneos/$APP_NAME.app"

  install_and_launch() {
    local device_name="$1"
    local device_udid="$2"

    echo "== Installing to $device_name =="
    if ! xcrun devicectl device install app --device "$device_udid" "$IOS_APP_PATH"; then
      echo "install failed"
      return 1
    fi

    echo "== Launching on $device_name =="
    if ! xcrun devicectl device process launch --device "$device_udid" "$BUNDLE_ID"; then
      echo "installed ok, launch failed"
      return 1
    fi

    return 0
  }

  if install_and_launch "$IPHONE_NAME" "$IPHONE_UDID"; then
    IPHONE_STATUS="launched"
  else
    IPHONE_STATUS="failed (see log above)"
  fi

  if install_and_launch "$IPAD_NAME" "$IPAD_UDID"; then
    IPAD_STATUS="launched"
  else
    IPAD_STATUS="failed (see log above)"
  fi
else
  IPHONE_STATUS="build failed"
  IPAD_STATUS="build failed"
fi

echo
echo "== Summary =="
echo "Mac:    $MAC_STATUS"
echo "iPhone: $IPHONE_STATUS"
echo "iPad:   $IPAD_STATUS"
