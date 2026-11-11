# Release Notes — v1.1.1

Theme: Keep what you saved. A fixes-only update for backup restore, imports, and the paywall.

## IMPROVED

- **Restore respects your dates.** A restored backup no longer rewrites Date Modified, and the later Last Opened from either side is kept, so a restore cannot push something back into Forgotten.
- **Opening an item is no longer an edit.** Date Modified stays put when you open a link, so Date Modified order means what it says.
- **Addresses without https:// work.** Add Link and text import accept `example.com` and `www.example.com/page`.
- **Imports that stop at the free limit say so.** You keep the items already saved and get a summary with an Unlock button.
- **New previews arrive while you are in the library.** No backgrounding and reopening to get titles and images.

## FIXED

- **Restoring the same backup on two devices no longer deletes your links.** Each device used to remove the other's copy after sync. Both copies now stay until you delete one.
- **A preview no longer overwrites a title.** A title you edited or restored survives Refresh Preview.
- **Re-saving a link keeps its collection and Favorite.** Text import and URL drops used to clear both.
- **A deleted copy no longer wins.** When Tucked holds two copies of a link and one was deleted, the active copy now stays active instead of disappearing.
- **No crash on a long-press.** A link with a missing or unreadable address no longer takes the app down.
- **Selection ends when you switch views**, and Share is disabled when nothing shareable is selected.
- **Your draft survives the paywall.** Saving at the free limit in Add Link or the snippet editor opens the paywall over the editor, and the text is still there afterwards. On Mac, menu commands leave an open editor alone.
- **Pinch-zoom no longer re-decodes the image** on every frame.
- **The paywall finds its price after an offline launch** instead of showing a disabled button.
- **A library that cannot open shows a recovery message** and a Support link instead of crashing.
- **Removed items are cleared after 30 days**, as the app always said they would be.
- **A backup link cannot erase an image or snippet.** If a link's ID matches a saved image or snippet, the image or snippet is kept and the conflict is reported.

## Known limit

- If you restore the same backup on two devices before they sync, a link can appear twice. The extra copy stays until you delete it. A permanent fix needs a schema change, so it is planned as a later release.

## What to Test — 1.1.1 (16)

- **Restore:** Export a backup, open a few links, then restore the backup. Confirm Date Modified is unchanged and Last Opened keeps the later value.
- **Re-save:** Import a text file containing a URL you already saved in a collection. Confirm the collection and Favorite are unchanged.
- **Title:** Edit a link's title, then Refresh Preview. Confirm the title stays.
- **Paywall:** With the library locked, open Unlock. Confirm a real price appears.
- **Mac share:** Share a link from Safari with Tucked installed. Confirm it saves as a link.

---

# Release Notes — v1.1.0

Theme: Save highlighted text, a calmer library, and Tucked in the Mac menu bar. First shared update for iPhone, iPad, and Mac.

## NEW

- **Save highlighted text.** Select text in Safari or another app, share it to Tucked, and it saves as a snippet. Paragraphs and links stay intact, and the source page comes along when the app provides it. iPhone and iPad show the text before you save.
- **Tucked in the Mac menu bar.** Jump straight to Search, Links, Images, Snippets, or Settings. Closing the window keeps Tucked ready in the menu bar.
- **Get Info shows the preview image** at the top of the sheet.

## IMPROVED

- Refreshed library cards with subtle shadows, and a cleaner sidebar with accent-colored icons.
- Select moved into the toolbar. Selection actions sit on a floating bar instead of over your cards.
- Add Link opens ready to type, with the URL keyboard.
- Smoother scrolling and window resizing. Previews load in the background, and new link previews take less space.
- Cards, the sidebar, and editors fit better at the largest text sizes.

## FIXED (on Mac, from iOS 1.0.1 and 1.0.2)

- Unlock Tucked for Life and Restore Purchases are in Settings, any time.
- Save to Tucked explains the free limit clearly instead of showing an error.
- The free limit applies only once Tucked for Life can be purchased.

## What to Test — 1.1.0 (15)

Build 15 has the same app code as build 14. Spot-check only:

- **Highlighted text:** Share selected text from Safari. Confirm it saves as a snippet.
- **Mac menu bar:** Open Links and Images from the menu bar. Close the window, then reopen Tucked from the menu bar and from the Dock.

---

# Release Notes — v1.0.2

Theme: Easier to unlock, clearer about the free limit.

## NEW

- **Unlock Tucked for Life** and **Restore Purchases** now live in Settings, so you can buy or restore without waiting to hit the limit.
- Settings → About links to the Privacy Policy, Support, and the Low Effort Apps website.

## IMPROVED

- When Save to Tucked reaches the 10 free bookmarks, the Share Sheet now says so plainly and explains how to unlock, instead of showing a red error with a Retry button that could not work.

## FIXED

- The 10-bookmark limit applies only once Tucked for Life can be purchased, so nobody hits a paywall they cannot pay through.

## What to Test — 1.0.2

- **Settings unlock:** With a locked library, open Settings and tap Unlock Tucked for Life. Confirm the paywall opens, then try Restore Purchases.
- **Share at the limit:** With 10 bookmarks saved and Tucked locked, share a link from Safari. Confirm the message explains the limit and only Cancel is offered.
- **After unlocking:** Share a link again and confirm it saves.

---

# Release Notes — v1.0

Theme: Save links, images, and text snippets in one native library across iPhone, iPad, and Mac, with tools that bring forgotten saves back into view.

## NEW

- Save links, images, screenshots, and text snippets in a single library for iPhone, iPad, and Mac.
- Save from anywhere with **Save to Tucked**: the iPhone and iPad Share Sheet lets you pick a Collection and mark Favorite before saving, while the macOS Share menu saves immediately in one click.
- Import images directly on Mac with `File ▸ Add Images…` and view any saved image in a full-screen zoomable viewer.
- Create text snippets in the app with an optional source URL, a card excerpt preview, full-text search across snippet bodies, and one-tap Copy Text.
- Organize items with single-membership Collections and an independent Favorites filter, with live item counts in the sidebar for All Items, Images, Links, Snippets, Favorites, and each collection.
- Surface neglected saves with **Forgotten** (never-opened items older than 30 days) and **Surprise me** (opens a random item from your current view).
- Inspect item metadata in the **Get Info** panel: title, URL, collection, Favorite status, and added, modified, and last-opened dates.
- Keep your library portable with versioned JSON backup and restore (including snippets and open history), plain-text URL import, and Netscape-compatible HTML bookmark export.
- Recover removed items from **Recently Deleted** for up to 30 days before permanent removal.
- Mirror your library across iPhone, iPad, and Mac with local-first storage and automatic duplicate URL reconciliation.

## IMPROVED

- Unified the responsive card grid across iPhone, iPad, and Mac, with smooth cell relayout during continuous iPadOS window resizing.
- Adopted native system accent colors and standard sidebar selection across platforms, paired with full Light and Dark appearance, Dynamic Type scaling, VoiceOver card labels, and macOS keyboard shortcuts.
- Simplified the multi-select bottom bar to evenly spaced icon-only actions so labels never stack or wrap on compact screens.

## FIXED

- Link metadata fetches now retry after temporary network failures and preserve existing preview images when a refresh returns no image.
- Enabled outbound network access in the sandboxed Mac app so links saved on Mac fetch titles and preview images directly.
- Share Extension storage errors now present a clear recovery message and log diagnostic details locally.
- Packaged the Mac app as `Tucked.app` and updated the macOS application menu title so Finder, Spotlight, Launchpad, and TestFlight all display **Tucked**.

## What to Test — 1.0

- **iOS/iPadOS Share Sheet:** Share a webpage from Safari and an image from Photos. Pick a Collection, toggle Favorite, and tap Save. Confirm both appear immediately in Tucked.
- **macOS Quick Save:** Share a link from Safari and an image from Finder using **Save to Tucked**. Confirm the save completes immediately with no Collection and Favorite off, even when Tucked is closed.
- **Mac Image Import:** Use `File ▸ Add Images…` (`⌘⇧I`) on Mac to import one or more images, then open an image card to test the full-screen zoomable viewer.
- **Snippets:** Create a text snippet with and without a source link. Test searching for a word inside the snippet body, copying the snippet text, and opening the source link.
- **Untuck flows:** Confirm **Forgotten** lists only never-opened items older than 30 days. Open an item (link, image, or snippet) and verify `Last Opened` updates in **Get Info** and removes the item from Forgotten. Tap **Surprise me** in the toolbar to open a random visible item.
- **Backup & Export:** Export a JSON backup from Settings, restore it, and verify collections, Favorites, snippets, and dates remain intact. Test plain-text URL import and HTML export.
- **iCloud Sync:** Verify cross-device sync across iPhone, iPad, and Mac. Remaining manual checks from `docs/verification/cloudkit-device-matrix.md` include Mac-originated create-bookmark sync, offline conflict resolution, airplane-mode Share Sheet capture, and the fresh-account Production sync check.
