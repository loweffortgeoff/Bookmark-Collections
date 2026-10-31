#!/bin/bash
# Build Tucked for the iOS Simulator, install it on the device $AD is bound to,
# launch with the seeded in-memory library, and wait for the grid.
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"
need_ad
FREE_LIMIT="${FREE_LIMIT-100}"

cd "$REPO_ROOT"
echo "== build =="
LOG="$(mktemp -t tucked-verify-build)"
if ! xcodebuild -project BookmarkCollections.xcodeproj -scheme BookmarkCollections \
    -configuration Debug -destination 'generic/platform=iOS Simulator' \
    -derivedDataPath "$DERIVED" build >"$LOG" 2>&1; then
  echo "FAIL: build. First error:" >&2
  grep -m1 -B2 -A2 "error:" "$LOG" >&2
  echo "full log: $LOG" >&2
  exit 1
fi
echo "build ok"

echo "== install =="
"$AD" install "$BUNDLE_ID" "$APP_PRODUCT" || { echo "FAIL: install" >&2; exit 1; }

echo "== launch =="
ARGS=(--launch-args -ui-testing)
[ -n "$FREE_LIMIT" ] && ARGS+=(--launch-args -free-limit --launch-args "$FREE_LIMIT")
"$AD" open "$BUNDLE_ID" --relaunch "${ARGS[@]}" >/dev/null || { echo "FAIL: open" >&2; exit 1; }

for _ in $(seq 1 20); do
  if "$AD" snapshot -i 2>/dev/null | grep -q '"Seeded Active"'; then
    echo "READY: seeded library on screen (RUN_ID=$RUN_ID)"
    exit 0
  fi
  sleep 1
done
echo "FAIL: seeded grid never appeared" >&2
exit 1
