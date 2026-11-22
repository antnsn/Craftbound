---
title: Guides
parent: Features
nav_order: 5
description: Where the routes come from, how counts are worked out, and real reagents.
---

# Guides

Craftbound ships five routes:

| Guide | Average crafts | Notes |
| --- | --- | --- |
| **Enchanting: Easiest** | 319 (331 for 9 in 10 players) | Four runed rods to make along the way. Disenchanting takes you from 2 to 20. |
| **Alchemy: Easiest** | 310 | Two steps use limited-stock vendor recipes (Rage Potion from Hagrus in Orgrimmar, Holy Protection Potion from Hula'mahi in the Barrens). |
| **Blacksmithing: Easiest** | 231 | Starts at **125**. Buy a Blacksmith Hammer first. Grinding stones are made along the way. The last three recipes need Cenarion Circle (Friendly, Honored) and Argent Dawn (Honored) reputation. |
| **Engineering: Easiest** | 361 | Two tools to make: Arclight Spanner and Gyromatic Micro-Adjustor. Gold Power Cores are made along the way. |
| **Leatherworking: Easiest** | 329 | Two limited-stock vendor recipes (Werg Thickblade, Jase Farlane). The last three need Cenarion Circle and Timbermaw Hold (Revered) reputation. |

Each route except Blacksmithing goes from 1 to 300.

Pick one with `/craft guide`, or by opening that profession's window.

## Where the numbers come from

The routes come from the Wowhead "Easiest" planner for WoW: Forever. Blizzard has never published skill-up chances, so the craft counts are simulated from the community's skill-up model. Craftbound shops for the **safe** count, which is enough for most players, and scales it as you go: halfway through a step, it only asks for the other half.

{: .warning }
Forever lowered the skill level of many old recipes, and neither guide has been playtested in Forever yet. Follow your real skill: Craftbound does, and a step ends when your skill reaches its end, however many crafts that took.

## Tools, stations and parts

- **Tools** stay in your bags: runed rods, the Blacksmith Hammer, the Arclight Spanner. Craftbound keeps a tool on the route until the last step that needs it. The hammer is bought, so it goes on the shopping list and the merchant button buys it.
- **Stations** (Anvil, Master Forge, Tanning Rack, Sewing Machine) are shown on the step. Stand next to one.
- **Parts** are reagents the route makes itself, such as a Solid Grinding Stone for Big Black Mace or a Gold Power Core for Gyrochronatom. The shopping list buys the part's own reagents (Solid Stone, Gold Bar) and counts the parts you already have. When a step is short of a part, the **Craft** button makes the parts first.

## Real reagents

Every time you open the profession window, Craftbound reads the real reagents of each recipe the guides use and remembers them for the account. From then on, the shopping list and the reagent rows use the game's numbers rather than the guide's.

The Alchemy guide needs this most. Its source disagrees with itself on *Major Discolored Healing Potion* (257-300): the route lists Plaguebloom and Murloc Eye, but the shopping list lists Ghost Mushroom and Gromsblood. Open the recipe once and Craftbound shops for whatever the game says.

## More guides

The route data is one file (`tools/data/profession-guides.json`). `tools/build_guides.py` turns it into the addon's `Guides.lua`. Adding a profession only means adding data.
