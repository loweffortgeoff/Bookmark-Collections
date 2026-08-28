# Glaze parity: text snippets and Mac image import

Date: 2026-08-28
Status: approved design, not yet implemented
Branch: `feature/snippets-and-add-images`

## Problem

A Glaze port of Tucked lives at `/Users/geoffreysilva/Glaze/Tucked`. It has
drifted ahead of the Swift app in two places, and it is the copy currently in
daily use. Keeping two implementations in step across two Macs costs more than
it returns, and the Glaze build gives up iPhone, iPad, CloudKit, and the system
Share Sheet to get there.

The Swift app is the one that ships. It must absorb the two features the Glaze
build added, and it must be able to read the Glaze library back.

Three concrete gaps:

1. **Text snippets.** Glaze has a third bookmark kind: a saved piece of text
   with an optional source link, its own sidebar destination, and its own
   editor. The Swift model has only `link` and `image`.
2. **Backup interop.** Glaze writes snippets into the *Swift-compatible* JSON
   backup under a top-level `snippets` key. The Swift decoder does not know
   that key and silently drops it. Every snippet in the Glaze library is
   currently unreachable from the Swift app.
3. **In-app image import on Mac.** Glaze has `File ▸ Add Images…`. The Swift
   Mac app captures images only through the Share menu.

## Decision

Add a `text` bookmark kind, teach the backup format the `snippets` key, and add
a Mac-only image file importer.

Do not port Glaze's macOS-shell choices back. They are platform decisions, not
features.

## Scope

**In scope**

- Text snippets: model, repository, sidebar destination, search, card, editor.
- The `snippets` key in JSON backup import and export.
- `File ▸ Add Images…` on macOS.

**Out of scope**

- The Glaze quick-capture panel and its global capture shortcut. macOS already
  captures through the Share menu.
- Sharing plain non-URL text from the iOS Share Sheet to create a snippet.
  Snippets are created in-app only in this pass.
- Glaze's Finder-style grid semantics (single click selects, double click
  opens). The Swift grid opens on a single activation and stays that way.
- Glaze's `localStorage` sort persistence. Swift sort behavior is unchanged.
- Photos-picker image import on iPhone and iPad. Remains in the backlog.

## Behavior

### Snippets

- A snippet holds a body of text, an optional title, and an optional source
  link.
- The title is optional at entry. When the user leaves it blank, the app
  derives one from the body: the first line with non-whitespace content,
  truncated to 80 characters with a trailing `…` when longer. When the body has
  no such line, the title is `Snippet`.
- A snippet never participates in link de-duplication. Two snippets with
  identical text are two snippets.
- Opening a snippet opens its editor. There is nowhere else for it to go.
  Editing and viewing are the same surface.
- A snippet with a source link still exposes **Open Link** so the source can be
  reached.
- **Copy Text** appears on the snippet context menu and copies the body.
- Snippets appear under **All Items**, **Favorites**, their collection,
  **Forgotten**, and **Recently Deleted** on the same terms as any other
  bookmark. They do not appear under **Links** or **Images**.
- Search matches the snippet body in addition to the existing title, domain,
  URL, and collection-name fields.

### Add Images (macOS)

- `File ▸ Add Images…` opens a file importer limited to image content types,
  with multiple selection allowed.
- Each chosen file is downsampled through the existing `ImageDownsampler` and
  saved through the existing `BookmarkRepository.saveImage`. No second image
  path is introduced.
- Imported images land with no collection and Favorite off, matching macOS
  Quick Save.
- The command and the importer are compiled only on macOS.

### Backup

- JSON export writes snippets under a top-level `snippets` array. The
  `bookmarks` array carries links only.
- JSON import reads the `snippets` array when present. A backup without the key
  imports exactly as it does today.
- Snippets are matched on `id` alone during import. They never enter the
  normalized-URL de-duplication path.
- HTML export stays links-only. Image and snippet records are omitted, as they
  are today.
- Preview and favicon binaries stay out of backups, unchanged.

## Data model

`Bookmark` gains one enum case and one stored property.

```swift
enum Kind: String, Codable, CaseIterable {
    case link
    case image
    case text
}

var snippetBody: String = ""
```

The property is named `snippetBody` rather than `body`. `body` on a type that
sits beside SwiftUI views reads as a view body at a glance. The backup record
keeps Glaze's `body` key; the two names meet in the import and export services,
which already map field by field. `Bookmark` is a `@Model`, not `Codable`, so
no `CodingKeys` are involved.

Snippets reuse existing fields rather than adding new ones:

| Field | Value for a snippet |
| --- | --- |
| `urlString` | the optional source link, or `""` |
| `normalizedURLString` | always `""`, so link dedupe never matches |
| `domain` | host of the source link, or `""` |
| `title` | user-supplied or derived |
| `metadataState` | `.ready` — a snippet is never enriched |
| `previewImageData`, `faviconData` | `nil` |

`normalizedURLString` staying empty is safe. `BookmarkRepository.save(url:)`
constructs a `NormalizedURL` before querying, and `NormalizedURL` throws on an
empty string, so the dedupe fetch is never issued with `""`. Image bookmarks
already rely on this.

### CloudKit

Both changes are additive and defaulted, so SwiftData handles them as a
lightweight migration. No migration plan, no versioned schema.

The CloudKit Development schema updates on the next run. The Production schema
is not yet deployed — it is still a release gate in
`docs/verification/cloudkit-device-matrix.md` — so this pass breaks nothing that
is already live. Deploying Production later must include `snippetBody`.

## Components

### `Data/Bookmark.swift`

Add the `text` case and `snippetBody`. Nothing else.

This file compiles into **both** targets. `BookmarkShareExtension` needs no
source change, but the extension scheme must be built as part of verification.

### `Domain/BookmarkRepository.swift`

- `saveSnippet(title:body:sourceURL:collection:favorite:) throws -> Bookmark`,
  shaped like the existing `saveImage`. Throws when the trimmed body is empty.
- `updateSnippet(_:title:body:sourceURL:) throws`, applying the same title
  derivation on edit.
- `deriveSnippetTitle(_ title: String, body: String) -> String`, the rule
  described under Behavior.
- `reconcileDuplicates()` already filters `kind == .link`. Unchanged.

### `Features/Library/LibraryDestination.swift`

- New `case snippets`.
  - title `Snippets`
  - symbol `text.quote`
  - accessibility identifier `library.snippets`
- `includes(_:)` returns `deletedAt == nil && kind == .text`.
- `.links` already filters `kind == .link`, so snippets stay out of it with no
  change.
- `matches(_:searchText:)` gains `bookmark.snippetBody`.

Sidebar counts come from the existing `count(in:)` and need no work.

### `Features/Bookmark/SnippetEditorView.swift` — new file

One view for create, edit, and view. Fields in order: Text, Title, Source link,
Collection, Favorite. Save is disabled while the trimmed body is empty.

The file is new rather than a branch inside `BookmarkEditorView`. A snippet
editor and a link editor share almost no fields.

### `Features/Library/BookmarkCard.swift`

The `preview` builder gains a `.text` branch: a text excerpt of the body on the
card's 16:9 canvas, in place of an image. The subtitle shows the source domain,
falling back to `Snippet`.

The card's existing fixed-canvas geometry is unchanged. Extract the excerpt
into its own small view type rather than growing the builder inline.

### `Features/Library/LibraryToolbar.swift`

The existing `library.addMenu` gains **New Snippet** and, on macOS,
**Add Images…** beside **Add Link**.

### `Commands/BookmarkCommands.swift`

- **New Snippet** ⌘T in the `.newItem` group.
- **Add Images…** in the same group, macOS only.
- **Copy Text** on the Bookmark menu, enabled for snippets.

### `Domain/BackupDocument.swift`

```swift
struct SnippetRecord: Codable, Sendable {
    let id: UUID
    let title: String
    let body: String
    let sourceUrl: String?
    let isFavorite: Bool
    let collectionID: UUID?
    let createdAt: Date
    let modifiedAt: Date
    let deletedAt: Date?
    let lastOpenedAt: Date?
}
```

Key names match the Glaze writer exactly, including the lower-camel `sourceUrl`
against the upper-case `collectionID`. The inconsistency is Glaze's; matching it
is the point.

`BackupDocument` gains `let snippets: [SnippetRecord]`, decoded with
`decodeIfPresent` defaulting to `[]` so every existing backup still restores.

### `Domain/LibraryExportService.swift`

`exportJSON` currently filters `kind != .image`. Once `.text` exists that filter
lets snippets into the `bookmarks` array as URL-less links, which the Glaze
importer would reject and the Swift importer would mangle. Change it to
`kind == .link` and emit a separate `snippets` array.

`exportHTML` already filters to links. Confirm during implementation; change
only if it does not.

### `Domain/LibraryImportService.swift`

After the existing bookmark loop, add a snippet loop:

- Skip records with an empty trimmed body.
- Look up by `id`. An existing match counts as a duplicate and is updated in
  place; a new record counts toward `newCount`.
- Resolve `collectionID` against the collections just imported; an unknown id
  becomes `nil`.
- Set `kind = .text`, `metadataState = .ready`, `normalizedURLString = ""`.
- Derive the title when the record's title is empty.

Both sides already use `.iso8601` date strategies and Glaze writes ISO-8601
strings, so no date-strategy work is required.

### `Features/Library/LibraryRootView.swift`

Hosts the `.fileImporter` for Add Images, wrapped in `#if os(macOS)`, and
presents `SnippetEditorView`.

## Error handling

- An empty snippet body is refused at the repository with a thrown error; the
  editor's Save stays disabled so the throw is a guard, not a user-facing path.
- An unparseable source link on a snippet is dropped, leaving `urlString` and
  `domain` empty. It does not fail the save. Glaze behaves this way, and a bad
  source link should not cost the user the text.
- A backup whose `snippets` entries are malformed skips those entries and
  continues. A malformed backup document as a whole still throws, as today.
- An image file that fails to read or downsample during Add Images is skipped
  and the batch continues. The count of skipped files is surfaced to the user.
  One unreadable file must not cost the rest of the selection.

## Testing

Unit (`BookmarkCollectionsTests`):

- Title derivation: blank title with multi-line body, leading blank lines, a
  body longer than 80 characters, a whitespace-only body.
- A snippet is not returned by link de-duplication, and two identical snippets
  both persist.
- `reconcileDuplicates` leaves snippets alone.
- `LibraryDestination.snippets` includes only `.text` records, and `.links` and
  `.images` exclude them.
- Search matches a term that appears only in `snippetBody`.
- Backup round trip: export → import restores snippets with ids, dates,
  collection, and favorite intact.
- **Import of a real Glaze export used as a checked-in fixture.** This is the
  test that proves the migration, not the synthetic round trip.
- Import of a pre-`snippets` backup still succeeds.
- JSON export puts no snippet in `bookmarks`, and HTML export contains no
  snippet.
- Add Images: a selected file is downsampled and saved as an `.image` bookmark.

UI (`BookmarkCollectionsUITests`):

- The `library.snippets` destination is reachable and shows its empty state,
  matching the existing destination coverage.

Build verification, both required:

```
xcodebuild -project BookmarkCollections.xcodeproj -scheme "BookmarkCollections" -destination 'generic/platform=iOS Simulator' build
xcodebuild -project BookmarkCollections.xcodeproj -scheme "BookmarkShareExtension" -destination 'generic/platform=iOS Simulator' build
```

## Migration path

Once this lands, the Glaze library moves across in two steps:

1. Glaze ▸ **Export JSON**.
2. Tucked ▸ Settings ▸ **Import JSON**.

This is what makes the `snippets` key load-bearing rather than cosmetic.

## Implementation order

1. Model, repository, and their unit tests.
2. Destination, search, card excerpt, and `SnippetEditorView`.
3. Backup `snippets` key, including the Glaze-export fixture test.
4. `File ▸ Add Images…` on macOS.

Each step ends with both schemes building and the unit suite green.

## Consequences

- `Bookmark.Kind` is no longer a two-case switch. Every `switch` over it must be
  revisited, including menu-command enablement, which the TODO already flags as
  not kind-aware for images.
- The Glaze project stops being the more advanced copy. It stays useful as a
  Mac-only scratch build, but the Swift app becomes the source of truth again.
- Deploying the CloudKit Production schema must now include `snippetBody`.
