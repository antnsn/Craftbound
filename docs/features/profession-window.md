---
title: Profession window
parent: Features
nav_order: 1
description: The panel beside the profession window, and the Craft button.
---

# Profession window

When you open Enchanting or Alchemy, Craftbound docks a panel to the right of the profession window and makes that profession's guide the active one.

```
Craftbound
Enchanting · Tried & Tested  (1-300)
[■■■■■■■■■■□□□□□□□□□□]  142 / 300 · ~171 crafts to go
Craft Enchant Bracer - Lesser Stamina x22 (to skill 164).
Tool: Runed Silver Rod
  Soul Dust                          18 / 22
[ Enchant (22 left) ] [ Show recipe ] [ Done ]
Route
 ✓ Tool: Runed Copper Rod
 ✓ 1-2 Dust to Motes
 > 132-164 Bracer - Lesser Stamina          x22
   Tool: Runed Golden Rod                   x1
   164-189 Boots - Lesser Agility           x27
Still to get: 4 reagents. Open the auction house to buy them.
Recipes ahead: 2g 49s
```

## The current step

- **The line in colour.** This is the step and its skill-up colour (orange, yellow, green, gray). Once the window is open the colour comes from the game, not the guide.
- **The reagent rows.** Each one shows what you have (bags and bank) against what the rest of the step needs, green when you have enough.
- **Craft.** It crafts as many as the step still needs, capped by what your reagents allow. For Alchemy that is one click for the whole batch.
- **Enchant.** It puts one enchant on the item in the matching slot: Enchant Chest on your chest, Bracer on your wrists, and so on. When that item already has an enchant, the game asks whether to replace it. The button then says **Replace enchant**, and clicking it answers yes. If you have nothing in that slot, the game asks you to pick an item.
- **Show recipe.** It selects the step's recipe in Blizzard's window.
- **Done.** It ticks the step off by hand. Use it for steps Craftbound can't see you finish, such as disenchanting.

When the button is greyed out, its tooltip says why: the recipe isn't learned, you are missing reagents, or the step isn't a craft. If you are missing reagents, the panel lists the guide's **alternatives** in their skill-up colour, so you can craft one of those instead.

## The route

Every step of the guide, in order:

- ✓ done, `>` current, with the crafts each step still needs on the right.
- **Click** a line to select its recipe.
- **Shift-click** a line to tick it off, or to undo a tick.
- **Hover** a line to see its reagents, its alternatives, the trainer cost and notes such as a recipe sold in limited stock.

## Ranks

When you can train the next rank (Journeyman, Expert, Artisan), a red line says so. Five points before your skill hits the cap, training becomes the current step. Craftbound sees that you have trained from your new maximum skill.

## Turning it off

`/craft toggle panel` hides the panel, and `/craft toggle select` stops Craftbound selecting the recipe when the window opens.
