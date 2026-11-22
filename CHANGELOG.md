# Changelog

## 0.2.2-alpha (2026-11-22)

- First version on CurseForge.
- **At a rank's cap** (75/75, 150/150, 225/225) Blizzard's Create and Create All buttons ask
  before they craft, since crafting gives no skill-up there; "Craft anyway" lets the clicks
  through until the skill or the cap changes. Craftbound's own Craft button already stopped.
  `/craft toggle cap` turns the question off.

## 0.2.1-alpha (2026-11-22)

- `/craft shots` takes screenshots of every Craftbound frame for the docs (the window, the
  editor, the export box, the tracker, and the profession window it opens itself; the auction
  house panel when the auction house is open).
- Releases are packed and published by GitHub Actions when a version is tagged.

## 0.2.0-alpha (2026-11-22)

- **Every guide is now Wowhead's "Tried & Tested in Forever" route, 1-300**, with the recipe
  data from its Forever catalog. They replace the "Easiest" routes, which the planner had worked
  out for one character (Blacksmithing started at 125). A character on an old guide moves to the
  new one for the same profession at login, keeping its history and stop; ticked steps are
  cleared because the steps changed.
- Blacksmithing from 1. The Blacksmith Hammer is a buy step, and Forever's better hammers count.
- Parts can be made of other parts (Engineering's Unstable Trigger needs Solid Blasting Powder):
  the shopping list goes down to the raw reagents.
- **The Craftbound window** (`/craft`, minimap left-click): every guide, built-in and your own,
  with its route and your skill. It replaces the guide picker; the tracker is now
  `/craft tracker` and the minimap's right-click.
- **Stop at 150, 225 or 300**: per character and guide. The route, the shopping list, the
  progress bar and "finished" all end there (`/craft stop 150` does the same).
- **What each stop costs** from your skill now: missing reagents at remembered prices plus
  recipes still to learn. Prices come from your own auction house scans (now remembered between
  sessions), Auctionator's database when it is installed, and vendor prices. Items without a
  price and old prices are said, never hidden.
- **Your own guides**: copy any guide and edit it (name, skill ranges, crafts, order, delete
  steps), or start a new one with your profession window open and add its recipes.
- **Share guides as text**: Export gives a `CB1:` string to paste anywhere; Import turns one into
  a custom guide. Imported text is read as data only and checked field by field.
- Three more guides from Wowhead's Forever data: Tailoring, Cooking and First Aid (1-300). They
  keep Forever's own recipes (Runecloth Cuffs, the Venomspew set), stations (Loom, Spinning
  Wheel, Iron Oven) and reputation. Bolts are made along the way.
- Recipe hints name the vendors of your own faction, and say when a recipe is known from the
  start, a quest reward or a drop. Cooking and First Aid say how to learn Expert (a book) and
  Artisan (a quest).
- Vendor reagents from the imported data (spices, bleach, dyes, threads) are bought at
  merchants, never searched at the auction house.
- A painted icon: in the addon list, on a new minimap button (collected by minimap addons
  through LibDBIcon when one is loaded), beside the panel titles and as the docs logo.
- Steps can need several tools (hammer, spanner, micro-adjustor) and a station (anvil, loom,
  oven). A bought tool (the Blacksmith Hammer) is its own step, shopped for and bought at the
  merchant.
- Parts made along the way (grinding stones, bolts, cured hides): the shopping list buys
  their reagents, and **Craft** makes the parts before the step that needs them.
- Recipe notes name the reputation they need.
- Button labels are cut off inside the button instead of spilling past it.
- Fixes from the first in-game look: the panel docks beside the profession window's side tabs
  instead of over them, and route steps you can't learn yet are grey instead of orange.

## 0.1.0-alpha (2026-11-22)

First version, not yet tested in game.

- Two guides from 1 to 300: Enchanting (Easiest) and Alchemy (Easiest).
- A panel beside the profession window. It shows the current step and its skill-up colour,
  your reagents (what you have and what you need), and the whole route. It selects the step's
  recipe for you. The **Craft** button crafts what the step still needs, and enchants go on
  the matching equipped item.
- A **Craft the next step** key binding. Press it again to answer "replace the enchant?".
- A shopping panel beside the auction house. It lists what the rest of the route needs minus
  what is in your bags and bank, scans the prices, and buys with **Buy → Confirm** at the
  server's price. It warns you when the price has jumped.
- Reagents you buy count as yours while they wait in the mailbox, so they aren't offered again.
- A **Buy route reagents** button at merchants for vials and the Copper Rod.
- Progress is saved per character. A tracker shows where you left off, a message at login says
  what comes next, and steps you finish by hand can be ticked off.
- When you open a recipe in the profession window, Craftbound uses its real reagents instead
  of the guide's.
