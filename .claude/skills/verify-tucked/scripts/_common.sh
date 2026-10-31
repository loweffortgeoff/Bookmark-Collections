# Shared by the verify-tucked helpers. Source, don't execute.
BUNDLE_ID="com.loweffortapps.BookmarkCollections"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
DERIVED="$REPO_ROOT/build/VerifyDerivedData"
APP_PRODUCT="$DERIVED/Build/Products/Debug-iphonesimulator/Tucked.app"
RUN_ID="${RUN_ID:-$(date +%Y%m%d-%H%M%S)}"
ARTIFACTS="$REPO_ROOT/build/verify-artifacts/$RUN_ID"

need_ad() {
  if [ -z "${AD:-}" ] || [ ! -x "$AD" ]; then
    echo "FAIL: \$AD is not set to an executable agent-device path. Call device_open and export AD=<command>." >&2
    exit 2
  fi
}
