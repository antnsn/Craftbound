---
title: Guides
parent: Features
nav_order: 6
description: Where the routes come from, how counts are worked out, and real reagents.
---

# Guides

Craftbound ships one route per profession, all from 1 to 300: Wowhead's **Tried & Tested in Forever** routes, checked against Forever's own recipe data.

| Guide | Average crafts | Notes |
| --- | --- | --- |
| **Enchanting** | 297 | Five runed rods to make along the way, the last one Arcanite. Disenchanting takes you from 2 to 20. Mote of Magic is made from Strange Dust. |
| **Alchemy** | 316 | Vials from vendors. Superior Mana Potion is a limited-stock vendor recipe. The last recipe, Major Discolored Healing Potion, is taught by special trainers after a short questline. |
| **Blacksmithing** | 403 | Buy a Blacksmith Hammer first (Forever's Mithril, Arcanite or Twilight hammers count too). Grinding stones are made along the way. Ends with Forever's Bold Dirk (Pexmit, Mount Hyjal), which needs Azerothium Bars. |
| **Engineering** | 395 | Buy a Blacksmith Hammer; make an Arclight Spanner and a Gyromatic Micro-Adjustor. Bolts, powders, tubes, casings and triggers are made along the way. |
| **Leatherworking** | 413 | Hides are cured along the way. Gem-studded Leather Belt and Wicked Leather Gauntlets are limited-stock vendor recipes. |
| **Tailoring** | 363 | Bolts are made along the way. From 260 it uses Forever's own patterns: Runecloth Cuffs (Pexmit, Mount Hyjal) and the Venomspew set (Mishta, Cenarion Circle Friendly and Honored, at a Loom). |
| **Cooking** | 346 | Six fish recipes, all from vendors. Mightfish Steak needs an Iron Oven. Expert comes from the Expert Cookbook, Artisan from the Clamlette Surprise quest. |
| **First Aid** | 389 | Bandages. Expert comes from the book Expert First Aid - Under Wraps, Artisan from the Triage quest. The trainers for 240-300 are as in Classic, not yet confirmed on Forever. |

Pick one in the [Craftbound window](window.md) (`/craft`), or by opening that profession's window. You can also copy a guide, change it, or make and share your own: see the window page.

## Where the numbers come from

The routes are Wowhead's "Tried & Tested in Forever" routes, with the recipe data (skill-up colours, reagents, where each recipe is learned, stations and tools) from its Forever catalog (`tools/import_wowhead.py`). Blizzard has never published skill-up chances, so the craft counts come from the community's skill-up model. Craftbound shops for the **safe** count, which is enough for most players, and scales it as you go: halfway through a step, it only asks for the other half.

{: .warning }
Wowhead says it tested these routes in Forever, but Craftbound's counts are still estimates. Follow your real skill: Craftbound does, and a step ends when your skill reaches its end, however many crafts that took.

## Tools, stations and parts

- **Tools** stay in your bags: runed rods, the Blacksmith Hammer, the Arclight Spanner. Craftbound keeps a tool on the route until the last step that needs it. The hammer is bought, so it goes on the shopping list and the merchant button buys it.
- **Stations** (Anvil, Tanning Rack, Loom, Spinning Wheel, Cooking Fire, Iron Oven) are shown on the step. Stand next to one.
- **Parts** are reagents the route makes itself, such as a Solid Grinding Stone for Big Black Mace or an Unstable Trigger for Hi-Explosive Bombs. The shopping list buys the part's own reagents (Solid Stone; Mithril Bar, Mageweave and the trigger's Solid Blasting Powder, which is a part too) and counts the parts you already have. When a step is short of a part, the **Craft** button makes the parts first.

## Real reagents

Every time you open the profession window, Craftbound reads the real reagents of each recipe the guides use and remembers them for the account. From then on, the shopping list and the reagent rows use the game's numbers rather than the guide's.

Open a recipe once and Craftbound shops for whatever the game says, even if Forever changed it after the guide was made.

## More guides

The route data is one file (`tools/data/profession-guides.json`). `tools/build_guides.py` turns it into the addon's `Guides.lua`. Adding a profession only means adding data.
