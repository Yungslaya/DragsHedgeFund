# Drags Hedge Fund

Gold savings helper for **WoW: Forever** (Interface 16001).

**What's new (1.0.1):** mail your savings to your alt from the mailbox. Gold list fits the window.

Pick a goal, like your level 40 mount. Every time you make gold, it takes your % of that gain and tells you to put it away.

## How it works

1. Pick a goal: **Level 40 mount** (200g), **Level 60 epic mount** (2,000g), or type your own gold amount.
2. Set your % (20% to start). Each gold gain (loot, quests, sales, mail) gets its own cut.
3. The cuts add up in **To put away**.
4. Put that gold somewhere safe (mail it to a bank alt), then click **I saved it**.
5. Only gold you confirm counts as saved. Gold you had before is yours and is never counted.

The window shows **Saved so far**, **Still need**, and **To put away**.
The **List** shows every gain, its cut, and every time you saved.

When a goal is met and you pick a new one, saved starts again at 0.

## Mail it to your alt

At a mailbox a small Hedge Fund box shows next to the mail window.
Type your alt's name once (it remembers it), click **Fill in mail**, then press **Send** yourself.
It fills in the gold, a subject, and a note with the goal, the date and the amount.
When the mail goes out, that gold counts as saved.

## Overlay

A small box that stays on screen: goal, saved, still need, to put away (with a **Saved** button) and one tip.
Drag to move. Right-click to open the big window.

## Commands

- `/gg` - show or hide (also `/hedge`)
- `/gg goal` - pick a goal
- `/gg mini` - overlay on or off
- `/gg lock` - lock the overlay
- `/gg scale 1.2` - overlay size
- `/gg pct 20` - save 20% of each gain
- `/gg saved` - same as the I saved it button
- `/gg add 10` / `/gg set 50` - fix the saved amount (gold)
- `/gg reset` - clear the goal

## Install

Use the Dragbags Addon Updater, or copy the `DragsHedgeFund` folder into `World of Warcraft\_forever_\Interface\AddOns\` and fully restart WoW.

## Notes

- Mount and riding prices from Wowhead (Forever). Paladins and Warlocks get their mount from a class quest, so their goals count riding only.
- Tips are only for professions you have.
- Display only. It never buys, sells, mails or trades for you.
