# Deferred Beyond v1

These items were explicitly excluded from v1 and are not release blockers or committed roadmap work:

- Tags and multi-label organization.
- Offline webpage archives, reader mode, and standalone image storage.
- Shared or collaborative collections.
- Browser extensions.
- Custom accounts or non-CloudKit sync servers.
- Analytics or telemetry SDKs.
- StoreKit monetization.

The remaining v1 release gates are tracked in `docs/verification/cloudkit-device-matrix.md`, not here.

## Backlog

- The library grid's width-bucketed `.id()` relayout workaround (2026-07-19) uses a 20pt bucket, chosen conservatively without testing finer granularity. Revisit if resize still feels janky or visible bucket-boundary snapping shows up.
- Watch for the same stale-cell-geometry pattern (iPadOS 26 continuous window resize not re-proposing width to already-materialized cells) if other adaptive/resizable grid or list layouts are added later.
