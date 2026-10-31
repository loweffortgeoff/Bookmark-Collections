# Library destinations

The sidebar lists Library destinations (All Items, Images, Links, Snippets, Favorites, Forgotten), the user's Collections, and Recently Deleted, each with an item count. Choosing one shows only matching items in the grid.

## Sub-features

- `dest-sidebar` shows all destinations with counts.
- `dest-filter` shows only matching items after choosing a destination.
- `dest-back` returns to the sidebar from a grid.

## How to get to it (user POV)

- Launch the app; on iPhone the sidebar is reached with the `Bookmarks` back button in the nav bar.

## Driving it with agent-device

Preconditions: baseline seed, app on the All Items grid.

- **Open sidebar.** `$AD press 'label="Bookmarks"' --settle`. Snapshot lists cells `All Items`, `Images`, `Links`, `Snippets`, `Favorites`, `Forgotten`, `Reading`, `Recently Deleted` with counts 7, 1, 5, 1, 1, (none), 1, (none). Identifier nodes `destination.allItems` etc. are present.
- **Filter.** `$AD press 'label="Snippets" role=cell' --settle`. Heading text `Snippets`; the buttons include `Seeded Snippet` and exclude `Seeded Active`.
- **Images.** Repeat with `label="Images"`: only `Seeded Image`.
- **Back.** `$AD press 'label="Bookmarks"' --settle` returns to the sidebar.
- **Proof.** `scripts/evidence.sh dest-filter snippets` after the filter; the screenshot shows the `Snippets` heading and only the snippet card.

## Gotchas

- The sidebar remembers the last destination, so opening the app can land inside a grid rather than the sidebar.
- Tap the cell (`role=cell`). The `destination.*` identifier appears as a separate non-button node in the tree; the existing UI tests also tap the enclosing cell.
- Forgotten shows no count; it lists never-opened items older than 30 days, and the seed has none.
