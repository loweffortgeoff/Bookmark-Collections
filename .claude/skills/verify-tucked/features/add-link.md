# Add a link

A user saves a URL from inside the app; the link appears at the top of All Items immediately, before any metadata arrives.

## Sub-features

- `add-open` opens the Add Link sheet from the Add menu.
- `add-save` saves a valid URL and returns to the grid.
- `add-card` shows the new card with its domain as the title.
- `add-count` raises the Links and All Items counts by one.

## How to get to it (user POV)

- Choose `Add` in the navigation bar, then `Add Link`.

## Driving it with agent-device

Preconditions: baseline seed; app launched with `-free-limit 100` so the 10-item cap does not interfere; on the All Items grid.

- **Before.** `scripts/evidence.sh add-link before`.
- **Open menu.** `$AD press 'label="Add" role=button' --settle`. Menu shows `Add Link`, `New Snippet`, `New Collection`, `Settings`.
- **Open sheet.** `$AD press 'label="Add Link" role=button' --settle`. Nav bar `Add Link`, `Cancel`, a disabled `Save`, a URL field with placeholder `https://example.com`, `Collection, None`, and a `Favorite` switch.
- **Enter URL.** `$AD fill 'editable=true' "https://example.org/verify-add-link"`. `Save` becomes enabled. (Refs also work here; re-snapshot first.)
- **Save.** `$AD press 'label="Save" role=button' --settle`. Sheet closes; All Items shows a first card `example.org`.
- **After.** `scripts/evidence.sh add-link after`. Then `$AD press 'label="Bookmarks"' --settle`: All Items 8, Links 6.

## Gotchas

- Over the free limit (10 active items) the paywall appears instead of saving. Seed has 7, so keep `-free-limit 100`.
- The card title is the domain (`example.org`) until metadata fetch succeeds. The fetch needs network and is not required for the save.
- `Save` is disabled for empty or non-HTTP(S) input; that is the validation path, not a hang.
- Reusing a URL already saved updates the existing item instead of adding a duplicate.
