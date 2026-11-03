# Search bookmarks

Typing in the search field narrows the current destination's grid to matching items; no match shows an empty state with an `Add Link` action.

## Sub-features

- `search-match` filters the grid by title/URL text.
- `search-empty` shows an empty state for a query with no match.
- `search-clear` restores the full grid.

## How to get to it (user POV)

- Tap the search field labelled `Search bookmarks` at the bottom of the grid.

## Driving it with agent-device

Preconditions: baseline seed plus one saved link `https://example.org/verify-add-link` (run the [add-link](./add-link.md) recipe first); All Items grid.

- **Match.** `$AD fill 'label="Search bookmarks" editable=true' "verify-add"`, wait 2 s, `$AD snapshot -i`. The grid buttons are `example.org` only.
- **Empty.** `$AD fill 'role=search editable=true' "zzzz-no-match"`. Wait 2 s. Grid cards are gone; an `Add Link` button appears (the tree may also list stray `“match”`/`matches` buttons from the keyboard's suggestion bar).
- **Clear.** `$AD press 'label="Clear text"' --settle`, then `$AD press 'label="close"' --settle`. The full grid returns.
- **Proof.** `scripts/evidence.sh search match` after the match step; the screenshot shows the query and a single card.

## Gotchas

- The field's accessible label becomes its text once filled, so `label="Search bookmarks"` only works on an empty field. Re-target a filled field with `role=search editable=true`.
- The tree lags a filter by a second or two; an immediate snapshot can still show every card. Do not conclude search is broken from one early snapshot.
- Do not type `\n` through `$AD type`; it types the literal characters. The filter applies live and needs no submit.
- Search scopes to the selected destination, so a query in Favorites will not find non-favorites.
