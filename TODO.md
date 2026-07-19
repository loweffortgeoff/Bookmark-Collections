# Tucked TODO

## Next

_Nothing in flight._

The remaining v1 release gates (real-device CloudKit matrix, Production schema, TestFlight/new-account check) are tracked in `docs/verification/cloudkit-device-matrix.md`, not here.

## Backlog

- The library grid's width-bucketed `.id()` relayout workaround (2026-07-19) uses a 20pt bucket, chosen conservatively without testing finer granularity. Revisit if resize still feels janky or visible bucket-boundary snapping shows up.
- Watch for the same stale-cell-geometry pattern (iPadOS 26 continuous window resize not re-proposing width to already-materialized cells) if other adaptive/resizable grid or list layouts are added later.
- Photos-picker in-app image import.
- Files-importer image import (Mac).
- Drag & drop image import (Mac/iPad).
- `pageDescription` field + og:description fetch for the info panel.
- Image bookmarks are excluded from JSON/HTML export; design image-capable backup.

## Deferred Beyond v1

These items were explicitly excluded from v1 and are not release blockers or committed roadmap work:

- Tags and multi-label organization.
- Offline webpage archives, reader mode, and standalone image storage.
- Shared or collaborative collections.
- Browser extensions.
- Custom accounts or non-CloudKit sync servers.
- Analytics or telemetry SDKs.
- StoreKit monetization.

## Done

_Nothing checked off yet under this format — earlier v1 work landed before TODO.md tracked completions with dates. Going forward, completed items move here with a date (YYYY-MM-DD) instead of sitting in Next or Backlog._
