# Drags Hedge Fund

Gold savings helper for **WoW: Forever** (Interface 16001).

**What's new (1.1.0):** up to 5 goals at once, each with its own %. Mail your savings to your alt from the mailbox.

## How it works

1. Click **Goals** and add one or more goals: **Level 40 mount** (200g), **Level 60 epic mount** (2,000g), or your own name and gold amount. Up to 5.
2. Set the % for each goal (20% to start). Every gold gain (loot, quests, sales, mail) gives each goal its own cut.
3. The cuts add up in **To put away**.
4. Put that gold somewhere safe (a bank alt, for example), then click **I saved it**.
5. Only gold you confirm counts as saved. Gold you had before is yours and is never counted.

Each goal shows **saved of goal**, a bar, and **Still need**. A full goal stops taking cuts and says **GOAL MET!**
The **List** shows every gain, its cut, and every time you saved.

## Mail it to your alt

At a mailbox a small Hedge Fund box shows next to the mail window.
Type your alt's name once (it remembers it), click **Fill in mail**, then press **Send** yourself.
It fills in the gold, a subject, and a note with the date, the amount and each goal's part.
When the mail goes out, that gold counts as saved.

## Overlay

A small box that stays on screen: to put away (with a **Saved** button), total saved, one row per goal, and one tip.
Drag to move. Right-click to open the big window.

## Commands

- `/gg` - show or hide (also `/hedge`)
- `/gg goal` - add or change goals
- `/gg mini` - overlay on or off
- `/gg lock` - lock the overlay
- `/gg scale 1.2` - overlay size
- `/gg pct 20` - every goal saves 20%
- `/gg saved` - same as the I saved it button
- `/gg add 10 2` / `/gg set 50 1` - fix a goal's saved amount (gold, goal number)
- `/gg reset` - clear all goals

## Install

Use the Dragbags Addon Updater, or copy the `DragsHedgeFund` folder into `World of Warcraft\_forever_\Interface\AddOns\` and fully restart WoW.

## Notes

- Mount and riding prices from Wowhead (Forever). Paladins and Warlocks get their mount from a class quest, so their goals count riding only.
- Tips are only for professions you have.
- Display only. It never buys, sells, sends mail or trades for you. You press Send.
