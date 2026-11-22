---
title: Guides
parent: Features
nav_order: 5
description: Where the routes come from, how counts are worked out, and real reagents.
---

# Guides

Craftbound ships two routes, both from 1 to 300:

| Guide | Average crafts | Notes |
| --- | --- | --- |
| **Enchanting: Easiest** | 319 (331 for 9 in 10 players) | Four runed rods to make along the way. Disenchanting takes you from 2 to 20. |
| **Alchemy: Easiest** | 310 | Two steps use limited-stock vendor recipes (Rage Potion from Hagrus in Orgrimmar, Holy Protection Potion from Hula'mahi in the Barrens). |

Pick one with `/craft guide`, or by opening that profession's window.

## Where the numbers come from

The routes come from the Wowhead "Easiest" planner for WoW: Forever. Blizzard has never published skill-up chances, so the craft counts are simulated from the community's skill-up model. Craftbound shops for the **safe** count, which is enough for most players, and scales it as you go: halfway through a step, it only asks for the other half.

{: .warning }
Forever lowered the skill level of many old recipes, and neither guide has been playtested in Forever yet. Follow your real skill: Craftbound does, and a step ends when your skill reaches its end, however many crafts that took.

## Real reagents

Every time you open the profession window, Craftbound reads the real reagents of each recipe the guides use and remembers them for the account. From then on, the shopping list and the reagent rows use the game's numbers rather than the guide's.

The Alchemy guide needs this most. Its source disagrees with itself on *Major Discolored Healing Potion* (257-300): the route lists Plaguebloom and Murloc Eye, but the shopping list lists Ghost Mushroom and Gromsblood. Open the recipe once and Craftbound shops for whatever the game says.

## More guides

The route data is one file (`tools/data/profession-guides.json`). `tools/build_guides.py` turns it into the addon's `Guides.lua`. Adding a profession only means adding data.
