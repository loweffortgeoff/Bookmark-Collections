# Organize a bookmark

Long-pressing a card opens its context menu: Get Info, Favorite, Move, Edit, Share, Delete. Favorite is independent of collections.

## Sub-features

- `org-menu` shows the context menu entries.
- `org-favorite` marks the item Favorite; it appears in Favorites and raises the Favorites count.

## How to get to it (user POV)

- Long-press any bookmark card in a grid.

## Driving it with agent-device

Preconditions: baseline seed, saved link `example.org` (run [add-link](./add-link.md) first), All Items grid.

- **Menu.** `$AD longpress 'label="example.org"' --settle`; `$AD snapshot -i` shows buttons `Get Info`, `Favorite`, `Move`, `Edit`, `Delete`, and a Share control.
- **Favorite.** `$AD press 'label="Favorite" role=button' --settle`.
- **Second view.** `$AD press 'label="Bookmarks"' --settle`: Favorites count 2. `$AD press 'label="Favorites" role=cell' --settle`: buttons `example.org` and `Seeded Active`.
- **Proof.** `scripts/evidence.sh org-favorite favorites` on the Favorites grid.

## Gotchas

- The menu entry for an already-favorite item reads differently (an unfavorite label); the verified label for a non-favorite is `Favorite`.
- `Delete` in the menu acts immediately with no confirmation (see [delete-restore](./delete-restore.md)). Tap it deliberately.
- Move, Edit and Get Info were not driven in the seeding run; open them to extend this recipe.
