# Savings Pal changes (formerly Drags Hedge Fund)

Every released version, newest first.

## 1.5.1 (2026-11-17)

- **Update messages** now only come from real CurseForge releases, so you never hear about a version that isn't out yet.

Type `/reload` after updating.

## 1.5.0 (2026-11-16)

- **New name: Savings Pal.** Drags Hedge Fund is now called Savings Pal. It's the same addon with the same goals and saved gold. A one-time popup explains this after you update.
- New command `/savings`. The old `/gg`, `/hedge` and `/dhf` still work.
- **Update notices.** If someone in your guild or group has a newer version, you get one message saying an update is out in the CurseForge app. Only version numbers are shared, and nothing is sent in combat.

Fully restart WoW after updating (a new file was added).

## 1.4.4 (2026-11-14)

- The mailbox panel now works when another addon, such as TradeSkillMaster, replaces the mail window. It stands on its own (drag it where you like) and shows its own **Send mail** button after you fill the mail.
- The panel closes by itself when you leave the mailbox, and has a close button.

Type `/reload` after updating.

## 1.4.3 (2026-11-10)

Added separate gold, silver and copper fields to edit savings. Simplified the overlay and fixed mail postage. Type /reload after updating.

## 1.4.2 (2026-11-09)

Deduct 30 copper postage from bank-alt savings mail and show the net savings in the note. Update and /reload.

## 1.4.1 (2026-11-08)



- Quieter first-install setup: the full window stays closed at login. A locked savings overlay appears after you add a goal and hides in combat.

- Overlay tips and sounds start off for new installs. Existing users retain their explicit and legacy display preferences.

- Options now contains overlay, combat visibility, lock, tips and sound switches.

- /gg starter and /gg restore change display preferences only. Goals, percentages, saved gold, pending amounts, history and personal/shared scope are preserved.



Update, then /reload. Use /gg to add your goal.

## 1.4.0 (2026-11-07)



#### All your characters

- New **Characters** page with each character's gold and the combined total.

- Shows the character you are playing live. Alts show their last recorded balance and when it was recorded.

- The main window now shows **All characters** alongside **Can spend (here)**.

- Log into each alt once with the addon enabled to add it to the list.

- Counts gold in bags. It does not add unclaimed mail, auctions, bank balances, or other currencies.



#### Shared goals

- Choose **This character** or **Shared goals**.

- Shared goals take your chosen percentage of future earnings on participating characters.

- Click **Share** beside an existing personal goal to carry its target, stored amount, and pending contribution into shared goals.

- New alts start with shared goals after you enable sharing. Each character remembers its own selection.

- Shared goals are separate for each realm.



#### Use existing gold when you choose

- New **Use current gold for shared goals** button on the Characters page.

- Shows a preview before reserving anything.

- Example: 60g on one character and 40g on another, at 20%, reserves 12g and 8g.

- Excludes pending contributions and recorded stored savings from the available pool.

- The same existing balance cannot be reserved twice for the same goal.

- A changed balance invalidates the preview so you can review it again.

- Reserving increases **Put away**; it does not mark gold as **Stored** or move money.



#### Keep each character's money straight

- Each character owes only its own contribution.

- **I put it away** and the mailbox helper cannot confirm another alt's money.

- **Can spend** protects pending personal and shared contributions on the character you are playing.

- Existing personal goals and savings are preserved.

- New **Skip next own transfer** button: click immediately before collecting gold from your own alt. It ignores the next gold increase, then normal tracking resumes. The skip expires after 30 minutes.



#### Install — full restart required

Update, then fully close and restart WoW. This release adds account-wide saved data, so /reload alone is not enough.



Log into each alt once, then open /gg → Characters.



The addon tracks money and fills mail fields. You press Send and move the gold yourself.

## 1.3.0 (2026-11-06)



#### New look

- New blue bank-counter window with a stone frame.

- Large **Can spend** amount at the top.

- Separate **Put away** and **Stored** amounts.

- Roomier goal rows and a matching overlay.

- **History** shows your gains, savings cuts, and deposits.



#### Savings fixes

- All goal percentages together are limited to **100%**. A goal at **0%** is paused.

- Small gains cannot reserve more money than you received.

- Partial deposits now show the correct amount still owed for each goal and transaction.

- Unpaid transactions stay in the history until settled.

- Removing a goal releases that goal's unpaid reservations.

- The first gain is tracked even when you log in with no gold.

- Loading screens no longer reset the tracking baseline.

- **Can spend** and **Put away** show exact amounts, including copper.

- The window remembers when you leave it hidden.



#### Mail fixes

- Savings count only after a successful send.

- Failed mail and C.O.D. do not count as saved.

- Changing the recipient does not accidentally mark savings as sent.

- A draft cannot claim newer savings added after it was filled.

- Mailing savings no longer triggers a false spending warning.

- You still press Blizzard's **Send** button yourself.



#### Your current savings

Your existing goals, stored amounts, and amounts still owed carry over.



#### Install

Copy the DragsHedgeFund folder into _forever_\Interface\AddOns\.



If the addon is already installed, type /reload. First-time installations need a full WoW restart.

## 1.2.0 (2026-11-05)

- New **Can spend** line on the big window and the overlay: your bag gold minus **To put away**. Spend up to that and your savings stay safe.
- If you spend into your savings, it turns red (**Spent into savings: 50s**) and warns you once in chat with a sound.
- It turns green again by itself when you make enough gold back. Nothing you owe is ever lost.

Display only. It never sends mail, buys, sells or trades for you.

## 1.1.0 (2026-11-05)

- **Up to 5 goals at once.** Each goal has its own % (Mount 20%, Bags 10%...). Every gold gain gives each goal its own cut.
- One **To put away** total and one **I saved it** button for all goals.
- Goal cards: saved of goal, bar, **Still need**, and **GOAL MET!** when full. Full goals stop taking cuts.
- New **Goals** screen: add presets or your own goal, set each %, remove (two clicks).
- **Mail it:** at a mailbox, type your alt's name and click **Fill in mail**. It fills in the gold and a note with the date and each goal's part. You press Send. When it sends, the gold counts as saved.
- Gold list fits the window. Overlay grows to fit its tip and shows one row per goal.
- Shows "under 1%" instead of 0% when a little is saved.

Your old goal and savings carry over as goal #1.

Display only. It never sends mail, buys, sells or trades for you.

## 1.0.0 (2026-11-05)

First release.



- Pick a goal: Level 40 mount (200g), Level 60 epic mount (2,000g), or your own amount.

- Takes your % (20% to start) from every gold gain and adds it to **To put away**.

- **I saved it** button: click after you mail or bank the gold. Only then it counts as saved.

- Shows **Saved so far** and **Still need**.

- **List** of every gain, its cut, and every save.

- Small overlay that stays on screen, with a **Saved** button.

- Tips for your own professions, plus the value of your gray items.



Display only. It never buys, sells, mails or trades for you.



Install: copy the `DragsHedgeFund` folder into `_forever_\Interface\AddOns\` and fully restart WoW.
