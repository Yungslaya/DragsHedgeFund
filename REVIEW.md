# Character tracking and shared goals — 1.4.0

- Adds account-wide saved wallets, keyed by character GUID with a realm/name fallback.
- Preserves the per-character saved database and existing goals.
- Separates shared ledgers by realm. The all-character total still displays every recorded character.
- Shared pending entries have a character owner. Confirmation and mail cannot pay another character's reservations.
- Spendable gold protects pending obligations in both the personal and shared ledgers.
- Existing gold is excluded from automatic gain tracking. Pooled reservation requires a preview and confirmation.
- Pooled contributions use free recorded balances after pending amounts and recorded stored savings.
- Each character's existing balance can seed a goal once; confirmation rechecks the preview signature.
- Snapshot timestamps and bag-only scope are visible in the UI.
- Realm scopes and per-character mode preferences are independent.
- The explicit own-transfer skip ignores exactly one increase and expires after 30 minutes.
- Adds 12 checks to the prior 13, for 25 total. No live offline-alt API is assumed.

This adds a new SavedVariables registration and therefore requires a full client restart.
The module does not import other addons' private databases and does not move currency.


---

# Review and changes for 1.3.0

Reviewed the published main commit 32812d3 against the clean local checkout.

## Fixed
- Total goal percentages could exceed 100%, including reserving two copper from a one-copper gain. Percentages are capped and rounding is shared across goals.
- Empty-bag login discarded the baseline, missing the first gain. Zoning also reset the baseline. Zero is now valid and zoning reconciles changes.
- Partial deposits changed goal balances but left transaction records inconsistent. Each gain now has an unpaid amount for each goal, reconciled on load.
- Removing a goal left its unpaid records behind. Its reservations are now released from those records.
- History silently discarded unpaid gains after 300 rows. Only settled history is trimmed.
- Money formatting hid copper and silver at larger balances. Exact amounts are now available in the spendable and transfer figures.
- A post-send hook could read a cleared mail form and overwrite the earlier snapshot. Mail is observed at the Send button's PreClick; COD never credits savings.
- A draft could credit new reservations created after it was filled. Drafts are now limited to the original goal reservations still unpaid.
- Mailing savings could raise a false spending alarm. The send-in-progress state suppresses that alarm until success or failure.
- The login window overwrote the saved hidden preference while opening. It now preserves that preference.
- Sparse API return values could be truncated by unpack. Their explicit return count is preserved.

## Design
New blue bank-counter window and overlay using existing Blizzard fonts and textures.
Large Can spend amount; separate Put away and Stored amounts; one roomy row per goal.
No new media files are required.

## Validation
13 assertion-based checks, including 1,200 randomized gain allocations, pass under Lua 5.1 through lupa.
The fake-WoW checks fail on caught errors as well as uncaught errors.
Existing balances and pending reservations are retained and tested through migration.
Live-game appearance and mailbox integration still need an in-game check.

## Limits
PLAYER_MONEY reports observed balance changes, not guaranteed individual server transactions.
A copied draft whose gold amount is edited manually may have an out-of-date note; only the actual
observed send amount is credited, capped by the original reservation.
This review does not verify the historical riding/class-mount prices in Data.lua.
