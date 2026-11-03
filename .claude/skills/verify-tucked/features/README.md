# Tucked verification map

Maintained source for verifying Tucked's user-facing behavior on the iOS Simulator. Read this index, then use the matching feature file as the recipe. Harness, launch, and evidence rules are in [`../SKILL.md`](../SKILL.md).

## Baseline preconditions

- Run `scripts/launch.sh`, then `scripts/doctor.sh` must print `OK`. Launch uses `-ui-testing -free-limit 100`: in-memory store, CloudKit off, seeded library.
- Seed: sidebar counts All Items 7, Images 1, Links 5, Snippets 1, Favorites 1; collection `Reading` holds 1; Recently Deleted holds `Seeded Deleted`.
- Seeded cards: `Seeded Active` (favorite, in Reading, `example.com`), `Seeded Snippet`, `Seeded Image`, `Landscape 16:9 Preview`, `Square Preview`, `Wide`, `Portrait Preview With a Deliberately Long Two Line Title`.
- Never drive a simulator or app instance this run did not start.

## Driving conventions

- Every recipe starts from the baseline. Relaunch (`launch.sh`) between features that mutate data; the in-memory store resets on launch.
- Use selectors, not refs: `label="<exact text>"` with `role=button|cell|text|search`. Refs renumber on every screen change.
- Start each recipe from the sidebar: `$AD press 'label="Bookmarks"' --settle`, then pick the destination. The app remembers the last destination.
- After a filter or destination change, wait 1-2 s and re-snapshot; the tree can lag.
- `$AD` is the agent-device command from `device_open`.

## Proof and skip reporting

- Capture before and after with `scripts/evidence.sh <feature-id> <step>` (screenshot + accessibility snapshot).
- Mutation proof includes a second view (sidebar count or another destination), not just the card that changed.
- Record the feature ID and entry point with every artifact.
- Report an unreachable path with the attempted command and the unmet precondition. Do not report a skipped entry point as verified through another path.

## Features

- [Library destinations](./library-destinations.md) covers the sidebar, destination counts, and filtered grids.
- [Add a link](./add-link.md) covers the Add menu, URL save, and the new card.
- [Search bookmarks](./search.md) covers the search field, matching, and the empty state.
- [Organize a bookmark](./organize-bookmark.md) covers the card context menu and Favorite.
- [Delete and restore](./delete-restore.md) covers Recently Deleted round-trips.
- [Settings](./settings.md) covers the Settings sheet contents.

Not mapped yet: New Snippet, New Collection, Move, Edit, Get Info, image viewer, Surprise me, Select mode, Import/Export, paywall (`FREE_LIMIT=5`).
