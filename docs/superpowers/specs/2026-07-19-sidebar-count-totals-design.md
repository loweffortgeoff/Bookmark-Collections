# Sidebar Count Totals

## Summary

Add trailing item counts to the library sidebar so each destination and collection shows how many bookmarks it contains. Counts always appear (including zero). Recently Deleted is unchanged (no count).

## Goals

- All Items shows total active bookmarks.
- Images, Links, and Favorites show their respective active totals.
- Each collection row shows active bookmarks assigned to that collection.
- Counts match the grid filters for each destination (no silent divergence).
- Minimal change: no schema, CloudKit, or settings surface.

## Non-goals

- Count on Recently Deleted
- Hide zero counts
- Search-scoped or selection-scoped counts (sidebar is always global library counts)
- Sorting collections or destinations by count
- Badge chrome, color coding, or user preferences for counts

## Counting rules

Counts reuse the same inclusion rules as `LibraryDestination.includes`:

| Destination | Count includes |
|-------------|----------------|
| All Items | `deletedAt == nil` |
| Images | active and `kind == .image` |
| Links | active and `kind == .link` |
| Favorites | active and `isFavorite == true` |
| Collection (id) | active and `collection?.id == id` |

Soft-deleted bookmarks never contribute to library or collection counts. Favorite state is independent of collection membership (existing model behavior).

Always display the numeric count, including `0`.

## Architecture

### UI

`CollectionListView` gains access to bookmarks (via `@Query` on `Bookmark`, preferred for self-contained sidebar, or passed from `LibraryRootView` if that proves cleaner).

Each counted row is an `HStack`:

- Leading: existing `Label` (title + system image)
- Trailing: secondary-style `Text` of the integer count

Library section rows (All Items, Images, Links, Favorites) and each collection `NavigationLink` get this treatment. Recently Deleted keeps the current label-only row.

No new visual density, badges, or monospaced requirements beyond system secondary label styling suitable for a sidebar.

### Shared counting logic

Prefer counting through `LibraryDestination.includes` (or a thin helper that iterates bookmarks with that predicate) so sidebar totals and grid filtering stay aligned. Collection rows use `.collection(collection.id)`.

Do not invent a parallel set of filter conditions in the view.

### Data flow

SwiftData `@Query` supplies the live bookmark set. When bookmarks or collection assignments change, counts recompute and the sidebar updates. No denormalized count fields on models. No CloudKit schema impact.

### Scale

Personal-library scale is assumed. In-view filtering of the full bookmark array is acceptable; dedicated per-destination `#Predicate` queries are out of scope for this change.

## Edge cases

- Empty library: every library destination shows `0`.
- No collections: existing “Create Collection” empty state; no collection rows to count.
- Collection whose members are all soft-deleted: shows `0`.
- Bookmark in a collection and favorited: counted in All Items, Favorites, its kind filter, and that collection (same as multi-destination membership today).

## Testing

- Unit tests with a small fixture library asserting counts for All Items, Links, Images, Favorites, and named collections.
- No requirement for UI snapshot tests in this pass; if accessibility identifiers are needed for counts later, add them without blocking the feature.

## Implementation notes

- Primary touch: `CollectionListView.swift`.
- Likely reuse: `LibraryDestination.swift` (count helper if useful).
- Tests: extend or add alongside existing library/destination coverage (e.g. `LibraryFilteringTests` or a focused count helper test).
- Branch before feature work; do not land on `main` directly.

## Out of scope / backlog candidates

- Recently Deleted count
- Optional hide-zero preference
- Search-filtered sidebar counts
