# App Store Connect — Current Listing (v1.0)

Initial release listing for Tucked 1.0. Bundle ID `com.loweffortapps.BookmarkCollections`. Primary locale `en-US`.

## Subtitle (30 characters max)
Bookmarks, Images & Snippets — 28 characters

Rationale: The app name ("Tucked") does not contain any category keywords, so the subtitle carries the primary discovery terms. "Bookmarks", "Images", and "Snippets" name the three item kinds Tucked stores while indexing high-intent searches for bookmark managers, image/screenshot savers, and text snippet tools.

## Promotional Text (170 characters max)
Save links, screenshots, and text snippets from the Share Sheet on iPhone, iPad, and Mac. Forgotten and Surprise me bring back what you tucked away and never opened. — 165 characters

## What's New
Welcome to Tucked 1.0 — a native library for your links, images, and text snippets across iPhone, iPad, and Mac.

• Save links and images from the Share Sheet on iPhone and iPad, or in one click with Quick Save on Mac.
• Keep text snippets alongside your bookmarks with an optional source link and one-tap Copy Text.
• Organize with Collections and Favorites, or browse by Links, Images, and Snippets.
• Rediscover neglected saves with the Forgotten view and the Surprise me button.
• Back up and move your library anytime with JSON backups, plain-text URL import, and HTML bookmark export.

## Description
Tucked — Save it now. Actually find it later.

Tucked is a native bookmark library for iPhone, iPad, and Mac. It keeps the links, screenshots, and text snippets you want to hold onto in one clean visual grid — and helps you rediscover the things you saved weeks ago and forgot to open.

Three Kinds of Saves in One Place
• Links: Visual cards with webpage preview images, favicons, titles, and domains. Tucked strips tracking parameters automatically and merges duplicate links.
• Images & Screenshots: Save images from the Share Sheet or import them on Mac with File ▸ Add Images. Open any image in a full-screen zoomable viewer.
• Text Snippets: Save quotes, notes, code, or excerpts directly in Tucked with an optional source URL. Copy the text in one tap or search inside snippet bodies.

Capture From Anywhere
• On iPhone and iPad, the Save to Tucked Share Sheet lets you assign a Collection and mark Favorite right as you save.
• On Mac, Save to Tucked uses Quick Save: one click in any Share menu saves the link or image immediately without interrupting your work.

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

- 2026-10-14 (v1.0 release pass): Created initial `ASC_LISTING.md` from `README.md`, `CHANGELOG.md`, and `DECISIONS.md`. Because the app name "Tucked" carries no category keywords on its own, the subtitle ("Bookmarks, Images & Snippets") is dedicated to the three saved item types. Keywords target the "save links", "read later", "bookmark folder", and "screenshot/snippet" search clusters without claiming offline article archiving or multi-tag management.
