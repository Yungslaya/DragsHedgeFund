# Drags Hedge Fund

Gold savings helper for WoW: Forever (Interface 16001).

**What's new in 1.4.0:** gold totals across characters, shared goals, and an optional one-time contribution from existing gold.

## Starter setup (starter setup)

Start with `/gg` and add your own goal and savings percentage. No goals or saved gold are invented. The locked overlay appears after you add a goal and hides in combat. Overlay tips and sounds start off. Shared goals and other-character tools are available when you choose them.

Open Options to enable extras. `/gg starter` applies starter display options; `/gg restore` restores your previous choices. These presets never change goals, percentages, stored savings, pending amounts, transaction history or personal/shared scope. Existing users keep their choices.

## Start here

1. Fully restart WoW after installing this update. The new account-wide saved data needs a restart.
2. Log into each character once with the addon enabled.
3. Open /gg and click **Characters** to see your total and each character's balance.
4. Each character you are playing updates live. Alts show their last recorded balance and the date.
5. Only bag gold is counted. Bank balances, unclaimed mail, auctions and other currencies are not added.

## Personal and shared goals

- **This character** saves to that character's personal goals.
- **Shared goals** saves to the common goals for this realm.
- The current character remembers which mode you select. Enabling shared goals makes them the default for new alts.
- Click **Goals**, then **Share** beside an existing personal goal to move its target, stored amount and pending amount into shared goals.
- You can also select **Shared goals** and add a new goal.
- Each goal has its own percentage. The percentages in the selected mode total no more than 100%. Set 0% to pause a goal.
- Shared progress is visible on every character using Shared goals. Personal goals are preserved in the other mode.
- Other realms appear in the total, but have separate shared goals because their gold may not be transferable.

## Existing gold is optional

By default, only future gold increases get a cut. Logging into an alt does not count its existing gold as earnings.

To reserve a percentage of existing gold:
1. Select **Shared goals** and set their percentages.
2. Open **Characters**, then click **Use current gold for shared goals**.
3. Read the preview and click **Reserve it**.

Example: Alice has 60g and Bob has 40g. One shared goal at 20% reserves 12g from Alice and 8g from Bob.
The same existing balance is not reserved again for that goal. A new alt can contribute once it has been recorded.
Existing pending contributions and recorded stored savings are excluded from the available pool.
Alt balances are snapshots. Refresh them by logging into each character before making a pooled contribution.

Reserving money only increases **Put away**. It does not mark the money as stored or move it.

## Put the money away

Each character owes only its own contributions. Mail or bank that gold, then click **I put it away**.
The mailbox helper fills the recipient, amount and goal note. You press Blizzard's Send button.
On a successful send, only that character's contribution is confirmed.

**Stored** is confirmed savings. **Can spend (here)** is bag gold minus pending contributions on this character.
Personal contributions remain protected when you switch to Shared goals.

The main window shows **All characters** as well. This is remembered bag gold, not stored progress.

## Moving your own gold between alts

Receiving your own gold normally looks like a new gain to the money API.
Immediately before collecting an own transfer, open **Characters** and click **Skip next own transfer**.
The next money increase is ignored, even if it is loot instead. Normal tracking then resumes.
The skip expires after 30 minutes if unused. This does not transfer money for you.

## History and overlay

History shows recorded money increases, cuts and deposits. Partial deposits show what is still owed.
Unpaid entries are retained until settled. The newest 300 settled records are retained.
Blizzard may combine several balance changes into one money event.

The overlay shows this character's spendable amount, contribution due and goal progress.
Drag it to move; right-click opens the full window.

## Commands

- /gg, /hedge, /dhf: open or close
- /gg characters: character gold list
- /gg shared: save to shared goals
- /gg personal: save to personal goals
- /gg transfer: ignore the next incoming own transfer
- /gg goal: manage goals
- /gg mini: overlay on or off
- /gg lock: lock the overlay
- /gg scale 1.2: overlay size
- /gg pct 20: set each goal in the selected mode to 20%, capped to a combined 100%
- /gg saved: confirm this character's pending contribution in the selected mode
- /gg add 10 2 or /gg set 50 1: fix a goal's stored amount
- /gg reset: clear goals in the selected mode; Shared mode clears shared goals for this realm

## Install and tests

Install with the Dragbags Addon Updater, or copy DragsHedgeFund into _forever_/Interface/AddOns/.
This update needs a full WoW restart for the new account-wide saved-variable registration.

Install Python and lupa==2.8, then run: python tests/test_review.py
25 fake-WoW checks cover existing features, character switching, shared contributions, snapshots, pool confirmation and alt mail.
Live-game layout and mailbox integration still need an in-game check.

## Notes

Display only. It never buys, sells, trades or sends mail for you.
The preset riding and mount amounts are estimates from earlier Wowhead Forever research.
The character-gold approach was checked against BagSync's public events and gold modules:
https://github.com/Xruptor/BagSync/blob/master/wireframe/events.lua
https://github.com/Xruptor/BagSync/blob/master/modules/gold.lua
