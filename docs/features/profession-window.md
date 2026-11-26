---
title: Profession window
parent: Features
nav_order: 1
description: The panel beside the profession window, and the Craft button.
---

# Profession window

When you open a profession with a guide, Craftbound docks a panel to the right of the profession window and makes that profession's guide the active one.

![The Craftbound panel beside the Alchemy window]({{ '/screenshots/profession-window.png' | relative_url }})

## The current step

- **The line in colour.** This is the step and its skill-up colour (orange, yellow, green, gray). Once the window is open the colour comes from the game, not the guide.
- **The reagent rows.** Each one shows what you have (bags and bank) against what the rest of the step needs, green when you have enough.
- **Craft.** It crafts as many as the step still needs, capped by what your reagents allow. For Alchemy that is one click for the whole batch.
- **Enchant.** It puts one enchant on the item for it: the item in the **Enchant on** sidebar if you put one there, else the item you wear in that slot (Enchant Chest on your chest, Bracer on your wrists, and so on). When your own gear already has an enchant, the game asks whether to replace it. The button then says **Replace enchant**, and clicking it answers yes. If you have nothing in that slot, the game asks you to pick an item.

## Enchant on: items to enchant instead of your gear

With an Enchanting guide, a narrow sidebar sits beside the panel, with one slot for each kind of item the route enchants (Chest, Bracer, Cloak...).

- **Drag an item from your bags onto a slot.** From then on, every enchant of that kind goes on that very item instead of your gear. Use a cheap item you don't wear.
- **No questions for it.** When the game asks "replace the enchant?" or "bind it to you?" for that item, the same press answers yes. (If the game asks a moment later, the next press does.)
- **Right-click a slot** to clear it. A greyed-out slot means the item is no longer in your bags: your equipped item gets the enchants again.
- Only that exact item is used, never another copy of it.

## Overwrite my enchants

A button at the top of the panel, off by default. Turned on, every enchant without an item in the sidebar goes on your equipped gear and **replaces whatever enchant is on it today, without asking**. Turning it on asks you to confirm first; click it again to turn it off.
- **Show recipe.** It selects the step's recipe in Blizzard's window.
- **Done.** It ticks the step off by hand. Use it for steps Craftbound can't see you finish, such as disenchanting.

When the button is greyed out, its tooltip says why: the recipe isn't learned, you are missing reagents, or the step isn't a craft. If you are missing reagents, the panel lists the guide's **alternatives** in their skill-up colour, so you can craft one of those instead.

Reagents in your bank or mailbox count as owned, so Craftbound never asks you to buy them. When the bags are short and the rest is in the bank, the reagent says **N in bank**, the tracker says **Fetch: ...**, and **Craft** tells you to fetch them first. The bank is counted once you have opened it.

## The route

Every step of the guide, in order:

- ✓ done, `>` current, with the crafts each step still needs on the right.
- **Click** a line to select its recipe.
- **Shift-click** a line to tick it off, or to undo a tick.
- **Hover** a line to see its reagents, its alternatives, the trainer cost and notes such as a recipe sold in limited stock.

## Ranks

When you can train the next rank (Journeyman, Expert, Artisan), a red line says so. Five points before your skill hits the cap, training becomes the current step. Craftbound sees that you have trained from your new maximum skill.

At the cap (75/75, 150/150, 225/225) crafting gives no skill-up, so the **Craft** button and its key stop and say to train. Blizzard's own **Create** and **Create All** buttons ask first: the first click says you are at the cap, and **Craft anyway** lets your clicks through until your skill or the cap changes. At 300 nothing asks: you craft for the items then. `/craft toggle cap` turns the question off.

## Waypoints

The map button on the panel (and on the tracker), or `/craft way`, sets a waypoint to the nearest place on your side and continent for what the route needs next: the trainer for your next rank (an Expert or Artisan trainer when that's what you need), the trainer or vendor of the recipe you haven't learned yet, or a vendor that sells a reagent you're missing (vials, thread, dye). It sets the game map's waypoint and a TomTom one when you use TomTom. Where the trainers and vendors stand comes from Questie's database.

## At the trainer

![The trainer panel beside Doctor Marsh, Expert Alchemist]({{ '/screenshots/trainer.png' | relative_url }})

At a profession trainer a Craftbound panel sits beside the trainer window. It lists what your route needs from this trainer, up to your stop: the next rank, the recipes of the steps still ahead, and the recipes of parts those steps need (grinding stones, blasting powder). Each line says **train now**, **at** the skill it needs, or **not taught here** (a vendor or a special trainer has it).

**Train N** trains only the lines marked *train now*, so you don't pay for every recipe the trainer has. Recipes you know, steps you are already past, tools you have and anything after your stop are left alone. `/craft toggle trainer` hides the panel.

## Turning it off

`/craft toggle panel` hides the panel, and `/craft toggle select` stops Craftbound selecting the recipe when the window opens.

## Craft another recipe instead

Right-click a step in the route list to pick another recipe for it, for example when the guide's recipe is sold far away or the auction house has no reagents for it.

- The list shows the recipes you have learned that still give skill-ups, orange and yellow first. Click one to use it.
- The step, the **Craft** button, the tracker and the shopping list all follow your pick. The step's craft count stays the guide's estimate.
- When your pick turns grey, Craft stops and asks you to pick another.
- **Back to** *the guide's recipe*, at the top of the same list, undoes it. Picks are kept per character.
