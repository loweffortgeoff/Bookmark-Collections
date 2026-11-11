# App Store Connect — Current Listing (v1.1.1)

Initial release listing for Tucked 1.0. Bundle ID `com.loweffortapps.BookmarkCollections`. Primary locale `en-US`.

## Subtitle (30 characters max)
Bookmarks, Images & Snippets — 28 characters

Rationale: The app name ("Tucked") does not contain any category keywords, so the subtitle carries the primary discovery terms. "Bookmarks", "Images", and "Snippets" name the three item kinds Tucked stores while indexing high-intent searches for bookmark managers, image/screenshot savers, and text snippet tools.

## Promotional Text (170 characters max)
Save links, screenshots, and highlighted text from the Share Sheet on iPhone, iPad, and Mac. Forgotten and Surprise me bring back what you tucked away and never opened. — 168 characters

## What's New
Bug fixes and reliability.

• Restoring the same backup on two devices no longer deletes links. Extra copies stay until you delete one.
• Restoring a backup keeps Date Modified, and Last Opened keeps the later value, so a restore cannot send items back to Forgotten.
• Opening a link no longer changes Date Modified, and a preview refresh no longer overwrites a title you edited or restored.
• Re-saving a link keeps its collection and Favorite. Addresses typed without https:// now work.
• Imports that stop at the free limit keep what they saved and show a summary.
• New previews load while the library is open.
• The paywall finds its price after an offline launch, the image viewer no longer re-decodes on every pinch, and a library that cannot open shows a recovery message instead of crashing.
• On Mac, a backup link can no longer erase a saved image or snippet.

Known limit: if you restore the same backup on two devices before they sync, a link can appear twice. The extra copy stays until you delete it.

## Description
Tucked — Save it now. Actually find it later.

Tucked is a native bookmark library for iPhone, iPad, and Mac. It keeps the links, screenshots, and text snippets you want to hold onto in one clean visual grid — and helps you rediscover the things you saved weeks ago and forgot to open.

Three Kinds of Saves in One Place
• Links: Visual cards with webpage preview images, favicons, titles, and domains. Tucked strips tracking parameters automatically and merges duplicate links.
• Images & Screenshots: Save images from the Share Sheet or import them on Mac with File ▸ Add Images. Open any image in a full-screen zoomable viewer.
• Text Snippets: Share highlighted text from any app, or write quotes, notes, code, or excerpts directly in Tucked with an optional source URL. Copy the text in one tap or search inside snippet bodies.

Capture From Anywhere
• On iPhone and iPad, the Save to Tucked Share Sheet lets you assign a Collection and mark Favorite right as you save.
• On Mac, Save to Tucked uses Quick Save: one click in any Share menu saves the link, image, or highlighted text immediately without interrupting your work.
• On Mac, Tucked stays in the menu bar for quick jumps to Search, Links, Images, and Snippets.

Clean, Predictable Organization
• Each item belongs to zero or one Collection, plus an independent Favorites list — no messy tag sprawl to maintain.
• Filter your sidebar by All Items, Images, Links, Snippets, Favorites, Forgotten, or any Collection, with live item counts on every row.
• Search across titles, domains, URLs, collections, and snippet text, and sort by newest, oldest, or title.
• Recently Deleted holds removed items for 30 days before permanent removal.

Untuck What You Forgot
• Forgotten surfaces items older than 30 days that you have never opened, so your library does not turn into a graveyard of unread links.
• Surprise me picks a random item from whatever view you are browsing and opens it right away.

Built for iPhone, iPad, and Mac
• Local-first storage keeps your library fast and available offline, with automatic iCloud sync across your devices.
• Full data portability: versioned JSON backup and restore, plain-text URL list import, and standard HTML bookmark export.
• Native Light and Dark appearance, Dynamic Type, VoiceOver support, and macOS keyboard shortcuts.
• No accounts, no subscriptions, no ads, and no analytics.

## Keywords (100 characters max)
link,read,later,save,article,clip,collect,folder,organize,screenshot,quote,note,research,url,stash — 98 characters

## Competitor Landscape
| App | Keyword Themes |
| --- | --- |
| GoodLinks | read later, save articles, bookmark manager, links, tag, highlight, sync |
| Raindrop.io | bookmark manager, collections, save links, web clipper, organize, folders |
| Anybox | bookmark & link manager, save links, images, notes, quick save, collections |
| Matter | read it later, article reader, queue, save links, newsletter, highlights |
| Flyleaf | read later, bookmarks, articles, offline reading, iCloud sync, tags |

Two adjacent clusters dominate search: **bookmark & link managers** (Raindrop.io, Anybox — focused on saving links, images, notes, and collections) and **read-later queues** (GoodLinks, Matter, Flyleaf — focused on saving articles to read later). Tucked bridges quick multi-kind capture (links, screenshots, snippets) with anti-hoarding rediscovery (Forgotten, Surprise me).

## Keyword Analysis

| Keyword | Purpose |
| --- | --- |
| link | Core category term; combines with "save", "organize", and "folder" ("save links", "link organizer") |
| read | Combines with "later" for high-volume "read later" / "read it later" searches |
| later | Second half of "read later" and "save for later" |
| save | High-intent action verb ("save links", "save articles", "save screenshots") |
| article | Captures read-later searchers saving articles and blog posts |
| clip | Web-clipper and snippet-clipping intent ("web clip", "clip text") |
| collect | Connects to collections and collecting links/images |
| folder | Common user term for single-collection bookmark organization ("bookmark folder") |
| organize | Core job-to-be-done ("organize bookmarks", "organize links") |
| screenshot | Directly matches Tucked's image Share Sheet capture flow |
| quote | High-intent use case for text snippets with source URLs |
| note | Captures users looking for a lightweight place to save links and notes together |
| research | Captures research-gathering workflows across links, screenshots, and quotes |
| url | Technical synonym for link ("url saver", "url manager") |
| stash | Natural synonym for "tucked" / link stashing ("link stash", "bookmark stash") |

**Already indexed by the name and subtitle, so not repeated:** tucked, bookmark(s), image(s), snippet(s).

**Dropped and why:**
- "collection": close variant of "collect", which saves 3 characters and combines broadly.
- "manager": covered by Apple's category indexing and lower intent than "organize" + "folder".
- "offline": Tucked stores your library and metadata locally, but it is not a full-text offline webpage reader; targeting "offline reader" would attract mismatched expectations.
- "tag": Tucked deliberately uses single-collection membership instead of tags.
- "private" / "icloud" / "sync": page-read reassurance features rather than primary discovery queries.

**A/B rotation candidates:**
- "stash" ↔ "manager" (test whether explicit "bookmark manager" outranks the thematic synonym)
- "quote" ↔ "clipboard" (test whether snippet users search "clipboard" more often than "quote")
- "research" ↔ "curate"

## Notes

- 2026-11-10 (v1.1.1 release pass): Fixes-only What's New. Promotional Text and What's New transferred to both the iOS and macOS 1.1.1 versions and read back; Subtitle and Keywords are unchanged. Description was not transferred: the live copy on both versions is 2,328 characters and ends at "macOS keyboard shortcuts", while this file adds a closing "No accounts, no subscriptions, no ads, and no analytics" line. Decide whether to add that line before submission.

- 2026-11-06 (v1.1.0 release pass): New What's New for the first shared iOS and macOS update. Promotional Text names highlighted text instead of text snippets. Description adds highlighted-text capture and the Mac menu bar. Subtitle and Keywords unchanged.

- 2026-10-14 (v1.0 release pass): Created initial `ASC_LISTING.md` from `README.md`, `CHANGELOG.md`, and `DECISIONS.md`. Because the app name "Tucked" carries no category keywords on its own, the subtitle ("Bookmarks, Images & Snippets") is dedicated to the three saved item types. Keywords target the "save links", "read later", "bookmark folder", and "screenshot/snippet" search clusters without claiming offline article archiving or multi-tag management.
