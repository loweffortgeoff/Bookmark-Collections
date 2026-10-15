# Tucked Paywall Design

## Goal

Let people save 10 active bookmarks for free, then offer Tucked for Life as a $4.99 lifetime unlock.

## Scope

- Count active links, images, and snippets. Deleted items do not count.
- Existing links remain editable. Export, deletion, and existing-item access remain free.
- Apply the limit to every new-save path: app editors, drag and drop, imports, and the Share extension.
- Use StoreKit 2 with one shared non-consumable product: `com.loweffortapps.BookmarkCollections.tuckedforlife`.
- Show the paywall only in the containing app. The Share extension reports that the limit is reached and directs people to Tucked.
- `Beta` bypasses monetization. `Release` enables it. The compiled build setting controls this; receipt detection is not used.

## Design

`BookmarkLimit` is a shared, pure rule. It permits a create when Tucked for Life is active or fewer than 10 non-deleted bookmarks exist. Re-saving an existing URL is an update and is permitted. Restoration and imports that would create more than 10 active bookmarks require Tucked for Life.

`Storefront` owns StoreKit product loading, entitlement refresh, purchases, restores, and transaction updates. It is injected at the app root. A paywall sheet uses that state for its price, progress, errors, purchase, and restore actions.

Each save surface converts a `limitReached` result into one user-facing action: present the paywall in Tucked, or show an extension error that asks the person to open Tucked. No StoreKit UI runs inside the extension.

The iOS/iPad archive and macOS archive remain separate. They use the same bundle ID, App Store Connect app record, and lifetime product for universal purchase.

## Constraints

- SwiftUI and StoreKit 2 only. Do not add dependencies, analytics, accounts, subscriptions, or trials.
- Respect Dynamic Type, VoiceOver, light and dark mode, and system tint.
- Bundle ID: `com.loweffortapps.BookmarkCollections`.
- Merge only after a sandbox test purchase succeeds on a real device.
