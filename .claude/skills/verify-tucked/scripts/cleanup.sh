#!/bin/bash
# Stop what this run started. Keeps build cache and all evidence.
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"
need_ad
"$AD" close "$BUNDLE_ID" >/dev/null 2>&1 || "$AD" close >/dev/null 2>&1 || true
echo "closed agent-device session. Evidence kept in $REPO_ROOT/build/verify-artifacts/. Call device_close for the device you opened."
