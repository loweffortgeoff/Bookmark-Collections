# Tucked 1.0 (9) TestFlight files

Source: f34b8c6. Use Tucked Release on iPhone and native Mac. Both 1.0 (9) builds are Valid and In Beta Testing for the existing internal group. What to Test is saved. No App Review submission or branch merge occurred.
Export a real-library backup before testing. These imports change the library and can sync to other devices on the same iCloud account. Deleting the app does not prove that the library or purchase history is empty.

## Prepare

1. Install version 1.0 (9) through TestFlight on each device.
2. Use a disposable library with zero active items for the exact counts below. Wait for CloudKit to settle. Do not erase a real library to make these counts match.
3. Start with a sandbox purchase account that does not own Tucked for Life. Keep the iCloud library account separate from the sandbox purchase account.
4. Confirm Settings does not show the unlocked Tucked for Life badge. If it already does, the free-gate checks are not valid until the test purchase state is reset.
5. Import each JSON file through Settings > Import Links. Select the .json file in the file picker. On iPhone, transfer the files with AirDrop or save them in Files.

## Check JSON while locked

| Order | File | Expected result |
| --- | --- | --- |
| 1 | 01-seed-10-free.json | Import succeeds. All Items = 10, Links = 9, Snippets = 1. TF Seed Collection appears. Link 01 and the snippet are Favorites. |
| 2 | 02-update-same-10.json | Import succeeds. Count stays 10. Collection becomes TF Updated Collection. Link 01 becomes TF Updated Link 01. Link 02 becomes a Favorite. Snippet becomes TF Updated Snippet with an updated body. |
| 3 | 03-same-url-new-id.json | Import succeeds. Count stays 10. Link 01 becomes TF Duplicate Updated Link 01. The extra UUID, tracking parameter, and fragment must not create a second card. |
| 4 | 04-reject-11-new.json | Import is blocked. Count stays 10. TF REJECTED - must not appear is absent. No TF Rejected Link cards appear. Existing titles, Favorites, snippet, and collection remain intact after relaunch. |
| 5 | 05-expand-to-12-after-unlock.json | Before purchase, import is blocked. Count stays 10. This file adds two links to the ten-item seed library. |

At ten, try one new link, one new snippet, an image, and Share capture. Each new item must be blocked. Existing edits, duplicate-link updates, opening items, and JSON/HTML export must still work. Verify rejected Share capture shows a useful failure with Cancel/Retry. After deleting one disposable item, one new item can be saved; the count returns to ten. Restore the original fixture state before continuing if you changed it.

## Check purchase and restore on both platforms

1. Restore with an account that owns nothing. Confirm a clear no-purchase result.
2. Open the paywall and complete the sandbox Tucked for Life purchase. Confirm the sandbox sheet before approving the transaction.
3. Confirm the paywall closes, the stale restore error disappears, and Settings shows Tucked for Life in the same app session. Record any Mac case where payment succeeds but the app stays locked.
4. Import 05-expand-to-12-after-unlock.json. Count becomes 12: 11 links and one snippet. This file restores the seed titles and TF Seed Collection name.
5. Save another new item through the app and through the Share Extension. Confirm each survives relaunch. Counts will now be greater than 12.
6. Quit and reopen. Confirm access stays unlocked. Check offline access after ownership has been established.
7. On the other platform, use the same purchasing account. Check automatic ownership recognition or Restore Purchases. Confirm access unlocks without a second charge. Repeat with a fresh sandbox account if you need to test purchase initiated on the other platform.

## Check duplicate updates above ten while locked

Use a disposable test purchase account. Preserve the same library while returning that account to an unowned sandbox state. Do not sign out of iCloud or delete the library for this check. If sandbox history reset or account switching is not available, mark this check blocked.

After the app refreshes ownership, confirm the Tucked for Life badge is absent. Reimport 05-expand-to-12-after-unlock.json. It must update existing records without increasing the count, even above ten. New growth must still be blocked. Reimport 04-reject-11-new.json. It must be rejected without creating its collection or links.

## Other submission gates

- On iPhone, share a Safari link and a Photos image below the cap and after unlock. Confirm exact content, durable saving, relaunch, and visibility in the main app.
- On Mac, close Tucked. Share a Safari link with Save to Tucked. Confirm the main app remains closed and the saved link appears when opened. Repeat with an image. Check free-limit failure and recovery.
- Use two TestFlight installations to check changes in both directions through Production CloudKit. Include creation, title edits, Favorites, collection moves, deletion, restore, and an offline edit followed by reconnection. Confirm no duplicates or silent loss.
- Complete the fresh-iCloud-account Production sync check and confirm the Production schema is deployed. A build upload does not close these gates.

Record each result with device, OS, build, purchase-account ownership state, starting count, action, observed count, and any error text. Stop submission if purchase succeeds while access stays locked, rejected import changes data, Share loses an item, or sync loses or duplicates data.
