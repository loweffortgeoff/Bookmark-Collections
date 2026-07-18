# Universal Bookmark App — v1 Design

Date: July 18, 2026
Status: Approved design

## Purpose

Build a native replacement for the discontinued Artifacts bookmark app. The app should make saving a web page from the system Share Sheet fast, make saved pages pleasant to recognize visually, and keep a complete usable library on iPhone, iPad, and Mac even when the network or iCloud is unavailable.

The app stores links only. Images, webpage archives, tags, collaboration, and social features are outside v1.

## Product principles

- Saving a link must succeed locally before any metadata or sync work begins.
- The visual library should retain the appealing browse-at-a-glance quality of Artifacts.
- Native system navigation and controls should adapt the experience across Apple platforms.
- A user's data must remain portable through first-class import and export.
- The app requires no custom account, hosted service, analytics, or third-party dependency.

## Platforms and technology

- One SwiftUI project targeting iPhone, iPad, and Mac.
- SwiftData is the local persistence layer.
- CloudKit mirrors the user's private database between devices.
- An App Group gives the main app and Share Extension access to the same local store.
- Link Presentation supplies page metadata and preview artwork where available.
- The project uses system fonts, SF Symbols, native lists, sheets, toolbars, menus, and alerts.

The product name is intentionally outside this design. The project may use `BookmarkCollections` as its working target name until product naming is settled.

## Information architecture

The library has four primary destinations:

1. **All Items** contains every active bookmark.
2. **Favorites** contains active bookmarks whose favorite flag is set.
3. **Collections** contains user-created collections and the bookmarks assigned to each.
4. **Recently Deleted** contains soft-deleted bookmarks for 30 days.

Tags do not exist in v1. A bookmark may belong to no collection or exactly one collection. Favorite status is independent of collection membership.

On Mac and iPad, the destinations appear in a native sidebar beside the visual grid. On iPhone, the same destinations use compact native navigation suited to the available width. The underlying content and behavior remain consistent across platforms.

## Core experience

### Saving from the Share Sheet

The Share Extension is the primary capture path.

1. The extension receives an HTTP or HTTPS URL and begins metadata loading concurrently.
2. It immediately shows the URL, any title already available from the host app, a collection picker, and a favorite control. Metadata loading never disables Save.
3. The user taps Save.
4. The extension immediately writes a minimal bookmark to the shared local store and closes.
5. Any metadata already loaded is included. A pending-metadata marker lets the main app or another device fetch the final title, domain, favicon, and preview image the next time it is active.
6. CloudKit later mirrors the local change.

If metadata loading fails, the saved card uses the domain and a deterministic system fallback. The user can refresh its preview later.

The main app also accepts pasted URLs on every platform and drag-and-drop URLs on iPad and Mac.

### Browsing

Bookmarks appear as responsive visual cards. Each card prioritizes preview artwork, followed by title and domain. Missing artwork receives a quiet system-styled fallback rather than an empty or broken card.

Tapping or clicking a card opens its URL in the default browser. Context menus provide Favorite or Unfavorite, Move, Edit, Share, Refresh Preview, and Delete. Mac also supports appropriate menu commands and keyboard shortcuts. Actions do not rely on small overlay buttons.

Search covers title, domain, full URL, and collection name. Users can sort by date added, date modified, title, or domain. Multi-selection supports moving, favoriting, sharing, and deleting several bookmarks on iPad and Mac where the platform interaction is appropriate.

### Collections and favorites

Users can create, rename, reorder, and delete collections. Deleting a collection requires confirmation because it is destructive to the organizational structure; its bookmarks remain in All Items with no collection. A bookmark can be moved between collections but cannot belong to more than one at a time.

Favorites are a simple flag. Favoriting never changes collection membership.

### Deletion and recovery

Deleting a bookmark moves it to Recently Deleted without an extra confirmation. Users can restore it or permanently delete it from there. Permanent deletion and Empty Recently Deleted require confirmation. Items older than 30 days are permanently removed during routine app maintenance.

## Data model

### Bookmark

- Stable UUID
- Original URL string
- Normalized URL string used for duplicate matching
- User-editable title
- Domain
- Optional favicon data
- Optional preview image data
- Favorite flag
- Optional collection relationship
- Creation date
- Modification date
- Optional deletion date
- Metadata state and last metadata refresh date

### Collection

- Stable UUID
- User-editable name
- Sort position
- Creation date
- Modification date

Preview and favicon payloads use external binary storage so large artwork does not bloat ordinary model records. All persisted properties have CloudKit-compatible defaults or optionality.

## URL normalization and duplicates

Duplicate detection is performed in app logic rather than through a persistence uniqueness constraint.

Normalization:

- Lowercase the scheme and host.
- Remove the fragment.
- Remove a default port.
- Normalize an empty path to `/`.
- Remove known tracking parameters such as `utm_*`, `fbclid`, and `gclid`.
- Preserve other query parameters because they may identify distinct resources.

When a normalized URL already exists, saving it does not silently create another bookmark. The save surface identifies the existing bookmark and lets the user update its metadata, favorite it, or move it to the selected collection. A soft-deleted match may be restored.

## Local persistence and CloudKit

Every supported device keeps a complete local copy of the library. Reads, saves, edits, moves, and soft deletes operate against SwiftData first. CloudKit synchronization occurs afterward through the private iCloud database.

The app remains fully usable when offline or when iCloud is unavailable. Settings shows quiet sync health information, including iCloud account availability and actionable failures the app can observe. It does not claim an exact sync time unless the underlying framework provides trustworthy evidence.

Conflicting edits to the same record resolve using its most recently modified version. If two offline devices independently save the same normalized URL with different identifiers, a reconciliation pass keeps the earliest-created record as canonical, carries forward Favorite when either record is favorited, applies the most recently modified title and collection, and removes the redundant record. Soft deletion synchronizes as a timestamp before eventual permanent removal, allowing recovery and avoiding immediate destructive conflicts.

No user-facing manual merge tool is included in v1. Export provides the safety valve if CloudKit or the local store encounters a serious problem.

## Import and export

Import accepts a UTF-8 text file containing one URL per line. Blank lines are ignored. Invalid lines are reported without preventing valid URLs from importing. Imports use the same normalization and duplicate behavior as interactive saves. Metadata enrichment runs after the URLs are safely stored.

Export supports:

- Standard HTML bookmarks for portability into browsers and other bookmark tools.
- Complete JSON containing bookmark fields, collection membership, favorites, and dates for lossless restoration of user-authored data and organization.

JSON import restores the complete app structure. Exported preview images need not be embedded because they can be regenerated; the original URL and user-edited metadata are preserved.

## Error handling

- Invalid or unsupported URLs are rejected with a specific correction message.
- A metadata failure leaves a valid saved bookmark and offers Refresh Preview.
- An App Group store failure keeps the Share Extension open and reports that the save did not complete.
- An unavailable iCloud account never prevents local work.
- Import reports invalid lines and counts new, duplicate, restored, and failed entries.
- Export writes atomically and reports failure without replacing a previous valid backup.
- Permanent destructive actions use native confirmation dialogs.

Empty states explain the next useful action: share or paste a first link, create a collection, or restore a deleted bookmark. They do not introduce onboarding screens.

## Accessibility and platform behavior

- Dynamic Type controls all text sizing; no fixed user-facing font sizes are required.
- Every card exposes a useful VoiceOver label containing title, domain, collection, and favorite state.
- Preview imagery is decorative when the title already communicates the destination.
- Controls meet platform touch-target expectations.
- Light and dark appearances are supported with semantic system colors.
- Keyboard navigation, focus, commands, and context menus receive explicit Mac and iPad testing.

## v1 scope

Included:

- Universal iPhone, iPad, and Mac app
- Share Extension and manual URL entry
- Responsive visual card grid
- All Items, Favorites, Collections, and Recently Deleted
- Collection creation, rename, reorder, and deletion
- Bookmark editing, moving, sharing, preview refresh, and soft deletion
- Search, sorting, and supported multi-selection actions
- Text, HTML, and JSON import or export paths described above
- Complete local storage with private CloudKit synchronization
- Accessibility, light and dark appearance, and keyboard support

Excluded:

- Tags
- Standalone image storage
- Offline webpage archives or reader mode
- Shared or collaborative collections
- Custom accounts or sync servers
- Browser extensions
- Analytics or telemetry SDKs
- Third-party libraries
- StoreKit monetization

Monetization is excluded from the first build so it cannot delay replacing the expiring app. It can be designed separately after the core library proves reliable.

## Verification

Automated tests cover:

- URL validation and every normalization rule
- Duplicate, update, move, and restore behavior
- Collection lifecycle and collection deletion behavior
- Favorite state independent of collection membership
- Soft deletion, restoration, and 30-day cleanup
- Text import result accounting
- HTML and JSON export correctness
- JSON backup round trips preserving user data and organization
- Metadata failure fallbacks
- Search and sort rules

Integration and UI tests cover:

- Share Extension writes becoming visible in the main app
- Offline saves remaining available after relaunch
- Invalid URL, failed metadata, empty state, and Recently Deleted flows
- Light and dark appearance
- Dynamic Type and VoiceOver labels
- Keyboard commands and context menus on Mac

Before release, real-device checks verify private CloudKit synchronization among an iPhone, iPad, and Mac, including edits made offline on more than one device. A successful local build alone is not considered synchronization evidence.

## Success criteria

The v1 is successful when a user can share a page from Safari, dismiss the Share Extension after a confirmed local save, find the bookmark immediately in the app, organize it into one collection or Favorites, and later see the same data on another signed-in device. Loss of network access or a metadata provider failure must not lose the URL. The complete library must be recoverable through exported data without relying on this app.
