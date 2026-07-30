# Untuck (Forgotten + Surprise me) — Design

**Date:** 2026-07-30  
**Status:** Approved for implementation planning  
**Approach:** A — filter destination (expandable to hub sheet B later)

## Problem

Saves go into Tucked and often never come back out. The library becomes a graveyard. Most bookmark apps optimize capture and folders; few help people *use* what they saved.

## Goal

Help people rediscover old, never-opened saves and surface one item on demand — without tags, AI, or a new data architecture.

## Product decisions

| Decision | Choice |
|----------|--------|
| Scope | Forgotten + Surprise me |
| Forgotten rule | Never opened **and** older than 30 days |
| Placement | Sidebar Forgotten + toolbar Surprise me |
| Surprise source | Current destination’s visible set when possible |
| Architecture | Approach A: `LibraryDestination` filter + shared open path |

**Feature name:** Untuck  
**UI labels:** Forgotten, Surprise me

## Behavior

### Forgotten (sidebar destination)

- Browseable library destination, same grid as Favorites / Links / Images.
- Membership: non-deleted items where `lastOpenedAt == nil` **and** `createdAt` is older than **30 days**.
- Sidebar shows a count.
- Search and sort work as on other destinations.
- Empty state (suggested copy):
  - Title: “Nothing forgotten yet”
  - Subtitle: “Items you’ve never opened that are older than 30 days show up here.”

### Surprise me (toolbar)

- Primary toolbar control near Sort (not only buried in the + menu).
- Label: “Surprise me”; symbol: `shuffle`.
- Picks one item uniformly at random from the **current destination’s filtered set**, including active search (same set the grid shows).
- Opens via the shared open path (stamp + open URL / image viewer).
- Enabled when there is ≥1 candidate; disabled when zero (no alert spam).
- Hidden or disabled in Recently Deleted (do not surprise from trash).
- macOS menu command **Surprise Me** is a nice-to-have in the same PR if cheap; not a blocker.

### What counts as “opened” (stamps `lastOpenedAt`)

| Action | Stamps? |
|--------|---------|
| Open link (card tap, context menu Open, menu command, Info “Open link”) | Yes |
| Open image viewer | Yes |
| Get Info only / edit / favorite / move collection | No |
| Share extension save | No (`lastOpenedAt` stays nil) |
| Metadata refresh | No |

If open fails (invalid URL), do **not** stamp.

**30-day clock:** Fixed constant (not a Settings control in v1). Implementation picks a single comparison style (simple `Date` interval vs calendar-day) and covers it with unit tests.

## Data model & sync

### Schema

Additive field on `Bookmark` (SwiftData, CloudKit-safe):

```swift
var lastOpenedAt: Date? = nil
```

| State | Meaning |
|-------|---------|
| `nil` | Never opened in Tucked (after this feature exists) |
| non-`nil` | Last time the user opened the link or image viewer |

**Existing library:** All current bookmarks start with `nil`. They become Forgotten only once they also age past 30 days. No migration job; no backfill of “opened.”

### Import / export

| Format | Behavior |
|--------|----------|
| JSON backup | Round-trip `lastOpenedAt` (optional key; missing → `nil`) |
| HTML export | Unchanged (no open metadata in Netscape format) |
| Text URL import | New saves get `lastOpenedAt = nil` |

### Domain helpers

Pure functions in Domain (e.g. `UntuckRules`) so approach B (hub sheet) can reuse them later:

```text
isForgotten(bookmark, now: Date, threshold: TimeInterval = 30 days) -> Bool
  // deletedAt == nil && lastOpenedAt == nil && createdAt <= now - threshold

surpriseCandidates(bookmarks, destination, searchText) -> [Bookmark]
  // same membership as LibraryDestination.includes + search filter
```

`LibraryDestination.forgotten.includes` delegates to `isForgotten`.

`BookmarkRepository.markOpened(_:)` (or equivalent):

- Sets `lastOpenedAt = now`
- Bumps `modifiedAt` so CloudKit mirrors the open across devices
- Open is a real user signal worth syncing (“I already saw this on my phone”)

### Duplicate reconciliation

When merging two records for the same normalized URL, for `lastOpenedAt`:

- If either is non-`nil`, keep the **later** (most recent) open time
- If both `nil`, stay `nil`

Favorite still ORs; title/collection still most-recently-modified. Open tracking is independent.

### CloudKit

Additive optional `Date?` field. Production schema must be deployed before shipping Untuck on Production-signed builds. Development container picks up the field on the next run with the model change.

## UI placement

### Sidebar order (Library section)

1. All Items  
2. Images  
3. Links  
4. Favorites  
5. **Forgotten** (new)

Then Collections, then Recently Deleted (unchanged).

| Property | Value |
|----------|--------|
| Title | Forgotten |
| SF Symbol | `clock.arrow.circlepath` (or similar if it reads poorly on device) |
| Count | Yes |
| Accessibility | Match existing patterns (`destination.forgotten` / `library.forgotten`) |

### Detail

Reuse `LibraryGridView`. No special card chrome in v1.

### Open-path constraint

Today, link cards may call `openURL` inside `BookmarkCard` when `onOpen` is nil, which bypasses parent stamping. v1 requires a **single open path**:

1. Parent supplies `onOpen` for links **and** images (or always routes through repository + open).
2. That path: `markOpened` → save → `openURL` / present image viewer.
3. Cover: card tap, context menu Open, macOS **Open** command, Info panel “Open link”.

### Settings

No new Settings UI in v1 (no threshold, no reset open history).

## Expandability (approach B later)

Approach A is the foundation for a future Untuck hub sheet:

| A builds | B reuses |
|----------|----------|
| `lastOpenedAt` | Same |
| Open stamping | Same |
| `isForgotten` / surprise candidates | Same |
| Forgotten destination | Hub “See all” → existing destination |

B is presentation only (~1–2 days after A): sheet + entry point calling the same helpers. No second data model.

## Testing

### Unit tests

| Area | Cases |
|------|--------|
| `isForgotten` | Never opened + old → true; never opened + young → false; opened once → false; soft-deleted → false; boundary at 30 days |
| Surprise candidates | Matches destination filter; respects search; excludes deleted; empty → empty |
| `markOpened` | Sets `lastOpenedAt`; bumps `modifiedAt` |
| Reconciliation | Later `lastOpenedAt` wins; nil vs date → date; both nil → nil |
| JSON import/export | Round-trips `lastOpenedAt`; missing key → nil |

### UI tests (light)

| Flow | Assert |
|------|--------|
| Forgotten destination visible | Sidebar row / accessibility id |
| Empty Forgotten | Empty state when no matches (if fixtures allow) |
| Surprise disabled when empty | Optional if easy |

Prefer unit coverage for rules; UI only for “row exists + navigates.”

## Risks (accepted for v1)

| Risk | Mitigation |
|------|------------|
| Entire existing library looks “unopened” | 30-day age gate |
| Open in Safari outside Tucked doesn’t clear Forgotten | By design; only in-app open counts |
| User forgets Surprise exists | Toolbar placement; hub (B) later if needed |
| Production schema lag | Deploy additive field before Production-signed Untuck release |

## Out of scope

- Untuck hub sheet (approach B)
- Configurable threshold / Settings
- “Not opened in 30 days” re-entry (opened once, then stale again)
- Sort-by last opened
- Notifications / widgets
- OCR / smart clustering
- Mark-as-unopened / reset history
- Tags, browser extensions, collaborative collections

## Success criteria

v1 is done when:

1. Forgotten sidebar destination filters correctly with count.
2. Opening a link or image removes it from Forgotten after stamp.
3. Surprise me opens a random item from the current visible set.
4. JSON backup round-trips `lastOpenedAt`.
5. Unit tests above pass; both app and share extension still build.

## Implementation sketch (not a full plan)

1. Add `lastOpenedAt`; update reconciliation, JSON import/export, `markOpened`.
2. Add `UntuckRules` + `LibraryDestination.forgotten`.
3. Wire sidebar row + empty state.
4. Centralize open path and stamp on all open surfaces.
5. Add Surprise me toolbar action.
6. Tests + dual-target build verification.
7. Production CloudKit schema deploy before Production-signed release.
