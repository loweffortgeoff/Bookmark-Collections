#!/bin/bash
# Read-only: is this instance worth driving?
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"
need_ad
fail() { echo "FAIL: $*" >&2; exit 1; }

[ -d "$APP_PRODUCT" ] || fail "no build at $APP_PRODUCT (run launch.sh)"
built_id=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$APP_PRODUCT/Info.plist" 2>/dev/null)
[ "$built_id" = "$BUNDLE_ID" ] || fail "built bundle id is '$built_id', expected $BUNDLE_ID"

tree=$("$AD" snapshot -i 2>&1) || fail "agent-device snapshot failed: $tree"
echo "$tree" | grep -q "App: $BUNDLE_ID" || fail "Tucked is not the foreground app"
echo "$tree" | grep -qE '"Seeded Active"|"destination.allItems"' \
  || fail "seeded library not on screen (relaunch with launch.sh; the store is in-memory)"
echo "built $(stat -f '%Sm' "$APP_PRODUCT/Info.plist"), foreground app is $BUNDLE_ID"
echo OK
