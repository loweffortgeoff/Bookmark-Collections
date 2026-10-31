#!/bin/bash
# Usage: evidence.sh <feature-id> <step-name>
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"
need_ad
[ $# -eq 2 ] || { echo "usage: evidence.sh <feature-id> <step-name>" >&2; exit 2; }
mkdir -p "$ARTIFACTS"
base="$ARTIFACTS/$1-$2"
"$AD" screenshot "$base.png" >/dev/null || { echo "FAIL: screenshot" >&2; exit 1; }
"$AD" snapshot -i >"$base.snapshot.txt" 2>&1 || { echo "FAIL: snapshot" >&2; exit 1; }
echo "$base.png"
echo "$base.snapshot.txt"
