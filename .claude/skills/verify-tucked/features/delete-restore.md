# Delete and restore

Deleting a card moves it to Recently Deleted without confirmation; from there it can be restored or permanently deleted.

## Sub-features

- `del-delete` removes a card from All Items and lowers the counts.
- `del-listed` shows the card in Recently Deleted.
- `del-restore` returns it to All Items.

## How to get to it (user POV)

- Long-press a card, choose `Delete`. Open Recently Deleted from the sidebar; long-press a card there for `Restore` and `Delete Permanently`.

## Driving it with agent-device

Preconditions: baseline seed plus saved link `example.org` (All Items 8).

- **Delete.** Go to the All Items grid, `$AD longpress 'label="example.org"' --settle`, `$AD press 'label="Delete" role=button' --settle`. The card disappears; sidebar All Items 7.
- **Listed.** `$AD press 'label="Bookmarks"' --settle`, `$AD press 'label="Recently Deleted" role=cell' --settle`. Buttons: `example.org`, `Seeded Deleted`, `Empty Recently Deleted`, `Empty`.
- **Restore.** `$AD longpress 'label="example.org"' --settle`; menu shows `Restore` and `Delete Permanently`. `$AD press 'label="Restore" role=button' --settle`.
- **Second view.** Back to the sidebar: All Items 8 again.
- **Proof.** `scripts/evidence.sh delete-restore deleted` on the Recently Deleted grid, and `... restored` on the sidebar.

## Gotchas

- You can only long-press `example.org` in a grid that contains it; if the app remembers Recently Deleted, switch destination via the sidebar first.
- `Delete Permanently`, `Empty`, and `Empty Recently Deleted` are destructive and show a confirmation; do not tap them without cause. They cannot be undone, even in the in-memory store.
