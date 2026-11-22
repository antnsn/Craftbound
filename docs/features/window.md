---
title: The Craftbound window
parent: Features
nav_order: 5
description: Every guide in one place, where to stop and what it costs, and your own guides to make and share.
---

# The Craftbound window

`/craft` or a left-click on the minimap button opens it. On the left is every guide: the ones
Craftbound ships and the ones you made or imported (marked **custom**). Click one to see it.

## Where to stop

Under **Stop at** are the rank caps inside the guide: 150, 225 and 300. Click one and the
route ends there for this character: the route list, the shopping list at the auction house, the
progress bar and the tracker all stop at that skill. A step that crosses the stop is cut short,
and a rank or a tool you only need past it is skipped. `/craft stop 150` does the same for the
active guide; `/craft stop end` goes back to the guide's end.

## What it costs

Under each stop is what you still need to spend to get there from your skill now: the reagents
you don't have, at remembered prices, plus recipes still to learn from trainers and vendors.

Prices come from, best first:

- **vendors**: buy prices from Wowhead's data and from every merchant you open;
- **your scans**: each price Craftbound finds at the auction house is remembered between sessions;
- **Auctionator**: its price database, when you have it installed (a full scan there fills in
  almost everything).

The line under the buttons says where the prices come from, how old the oldest is, and how many
items have no price yet. Scan at the auction house to fill those in.

## Your own guides

- **Copy and edit** makes your own copy of any guide. Change its name, the skill range of each
  step, how many crafts you shop for, the order, or delete steps.
- **New guide** starts an empty guide for the profession whose window is open. The recipes of
  that window are listed under the steps: click one to add it. A new step starts where the last one
  ends; set its range and crafts yourself (the game doesn't tell addons when a recipe turns
  yellow or green, so the count is an estimate you can change).
- **Delete** asks for a second click.

Your guides are saved for your whole account.

## Sharing

**Export** shows the guide as text starting with `CB1:`. Press Ctrl+C and paste it anywhere:
Discord, a forum post, a whisper. To use someone's guide, press **Import** at the top of the
window, paste the text and press Import: it becomes one of your custom guides.

Imported text is read as data only, never run, and only known guide fields with sensible
values are kept.
