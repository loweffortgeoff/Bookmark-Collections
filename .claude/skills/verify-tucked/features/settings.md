# Settings

The Settings sheet exposes library import/export, iCloud availability, and links to the privacy policy, support, and company site.

## Sub-features

- `set-open` opens Settings from the Add menu.
- `set-contents` lists Import Links, Export HTML, Export JSON, the iCloud status, and About links.

## How to get to it (user POV)

- Choose `Add`, then `Settings`.

## Driving it with agent-device

Preconditions: baseline seed; app launched via `launch.sh`.

- **Open.** `$AD press 'label="Add" role=button' --settle`, then `$AD press 'label="Settings" role=button' --settle`.
- **Contents.** `$AD snapshot -i` shows sheet `Settings` with `Done`, section `Library Data` (`Import Links`, `Export HTML`, `Export JSON`), `iCloud` with `iCloud temporarily unavailable`, and `About` with `Privacy Policy`, `Support`, `Low Effort Apps` links.
- **Proof.** `scripts/evidence.sh settings contents`.
- **Close.** `$AD press 'label="Done"' --settle`.

## Gotchas

- The simulator build is unsigned, so iCloud always reads `iCloud temporarily unavailable`. That does not test the real sync status.
- The About links open Safari; do not tap them in a run you want to stay inside the app.
