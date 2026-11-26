<!-- summary (CurseForge "Summary" field, at most 256 characters):
The ultimate addon for skilling up professions in WoW: Forever: tested routes 1-300 for eight professions, one-click crafting, auction house and vendor shopping, the trainer's recipes, where to stop and what it costs.
-->

# Craftbound

**The ultimate addon for skilling up professions in World of Warcraft: Forever.**

Levelling a profession is the most tedious job in the game. Craftbound does it with you, as close to automatic as the game allows, from the first craft to 300: it follows a tested route, crafts the next step, shops for what's missing, trains only the recipes you need, and stops where you want to stop.

Beside the profession window it shows the next step and crafts it with one button or key. At the auction house it shops for the rest of the route, and at vendors it buys what vendors sell. It remembers per character where you stopped, so you pick up right there.

**Full guide:** https://antnsn.github.io/Craftbound/

![The Craftbound window](https://antnsn.github.io/Craftbound/screenshots/window.png)

**Alpha:** Craftbound is new and not yet tested much in game. Tell us what doesn't work.

## Guides
- **Eight professions, 1-300**: Enchanting, Alchemy, Blacksmithing, Engineering, Leatherworking, Tailoring, Cooking and First Aid. The routes are Wowhead's "Tried & Tested in Forever", with Forever's own recipes, vendors, stations and reputation.
- **Follows your real skill**: a step ends when your skill reaches its end, however many crafts that took.
- **Tools, stations and parts**: runed rods, hammers and spanners stay on the route until the last step that needs them; the step says where to craft (anvil, loom, oven); grinding stones, bolts, cured hides and blasting powder are made along the way, and **Craft** makes them first.
- **Real reagents**: once you open a recipe, Craftbound uses the game's reagents, even if Forever changed them.

## The profession window
- **A panel beside it**: the step, its skill-up colour, the reagents you have and need, and the route ahead.
- **Craft** (button or key binding) crafts the step: as many as you can, never past your rank's cap. Enchants go on the right equipped item.
- **Enchanting, one press per enchant**: drag cheap items into the **Enchant on** sidebar and the route's enchants go on them, not your gear; or tick **Overwrite**. Either way Craftbound answers the game's "replace the enchant?" for you.
- **Craft another recipe instead**: right-click a step to use another recipe you know (one closer by, or one the auction house has reagents for); the shopping list follows.
- **Says what's missing**: a recipe to learn (and where, from the vendors of your faction), a rank to train, a tool to make.
- **Waypoints** to the nearest trainer for your next rank or recipe, the recipe's vendor, or a vendor for missing reagents (`/craft way` or the map button; TomTom too). The places come from Questie's database.
- **At the trainer**: a panel lists the rank and recipes your route needs from there, up to your stop, and one button trains only those.
- **Stops at the cap**: at 75/75, 150/150 and 225/225 crafting gives no skill-up, so Craft stops, and Blizzard's Create buttons ask before they craft.

![The panel beside the profession window](https://antnsn.github.io/Craftbound/screenshots/profession-window.png)

## The auction house and vendors
- **A shopping list** of what the rest of the route needs, minus what's in your bags, bank and mailbox.
- **Buy** the most-needed item in two clicks at the server's price, with a warning when the price jumped.
- **Vendor goods never at the auction house**: vials, thread, dye, flux and spices are bought at a merchant with one click.

![Shopping at the auction house](https://antnsn.github.io/Craftbound/screenshots/auction-house.png)

## The Craftbound window
- **Every guide** in one place (`/craft` or the minimap button), with its route and your skill.
- **Stop at 150, 225 or 300**: the route, the shopping list and the progress bar end there.
- **What each stop costs** from where you are: missing reagents at remembered prices (your scans, Auctionator's database when you have it, vendor prices) plus recipes still to learn. Missing and old prices are said, never hidden.

## Your own guides
- **Copy and edit** any guide: name, skill ranges, crafts, order, steps.
- **New guide**: with your profession window open, click recipes to add them.
- **Share**: Export gives a text you paste anywhere; Import turns someone's text into one of your guides. It is read as data only, never run.

![At the trainer: only what the route needs](https://antnsn.github.io/Craftbound/screenshots/trainer.png)

![Export a guide](https://antnsn.github.io/Craftbound/screenshots/export.png)

## Also in it
- **Per character**: progress, skills and history are kept per character; your own guides and remembered prices are shared by the account.
- **Tracker**: a small box that says where you left off, anywhere in the world.
- **Minimap button** (works with minimap addons through LibDBIcon) and an addon compartment entry.

## Commands
- `/craft`: open the Craftbound window
- `/craft tracker`: show or hide the tracker
- `/craft guide enchanting`: follow a profession's guide
- `/craft stop 150`: stop at 150 (or 225, 300; `end` for the guide's end)
- `/craft way`: a waypoint to what the route needs next (`way trainer`, `way recipe`, `way vendor`)
- `/craft list`: the shopping list in chat
- `/craft tick`, `/craft untick 3`: tick off a step by hand, or put it back
- `/craft reset`: forget this character's progress in the active guide
- `/craft toggle panel|shop|select|tracker|minimap|cap|trainer`: turn a part on or off
- `/craft help`: list every command

Key bindings (Key Bindings > AddOns > Craftbound): **Craft the next step** and **Auction house: buy next / confirm**.

## Works with
Nothing else is needed. **Auctionator** (optional) fills in prices for what each stop costs; **TomTom** (optional) adds an arrow to `/craft way`. Minimap addons (SexyMap, ElvUI and others) collect the minimap button.

## Credits
Where trainers and vendors stand comes from QuestieDB, part of [Questie](https://github.com/Questie/Questie), used under the GPLv3. Routes and recipe data: Wowhead's WoW: Forever profession guides. Craftbound is GPL-3.0-or-later.

## Ideas and contributions
- **Missing something?** New features are added on request: leave a comment here.
- **Feel free to contribute**: the code is on GitHub, https://github.com/antnsn/Craftbound (issues and pull requests welcome).

## Changelog
<!-- changelog:start -->
### 0.3.1-alpha (2026-11-26)

- **Overwrite** is a small checkbox on the guide's line now, not a full-width button: the
  route gets the room back.

### 0.3.0-alpha (2026-11-26)

- **Enchanting skips the Runed Arcanite Rod**: it was one skill point (294-295) for an Arcanite Rod
  (3 Arcanite Bars) and dear shards, and no enchant on the route needs it. Enchant Shield - Greater
  Stamina takes you to 295 instead (one more Dream Dust craft).
- **Craft another recipe instead**: right-click a step in the route list (profession panel) and
  pick any learned recipe that still gives skill-ups, for example when the guide's recipe is
  far away or not on the auction house. The step, Craft, the tracker and the shopping list all
  follow your pick; "Back to ..." in the same list undoes it. Kept per character.
- **Enchant on: items to enchant instead of your gear.** A sidebar beside the profession panel
  (Enchanting guides) with a slot per kind the route enchants: drag a cheap item from your bags
  onto it, and those enchants go on that item. The game's "replace the enchant?" and "bind it?"
  questions for it are answered for you. Without a pick the slot shows what you wear (that gets
  the enchant), and Craft's tooltip says which item the enchant goes on.
- **Overwrite my enchants** (top of the panel, off by default): enchants go on your equipped gear
  and replace whatever is on it: Craftbound answers the game's question for you. It warns you
  before it turns on.
- **Reagents in the bank**: they always counted as owned (nothing to buy), but now the
  profession panel shows "N in bank" on the reagent, the tracker says "Fetch: ...", and Craft
  says to fetch them instead of "Missing reagents". The mailbox likewise.
- The profession panel's route lists the steps up to your stop, and the rest as one line
  ("After your stop at 150: 14 more steps"; click it to change the stop), not ticked off as if
  they were done.
- The tracker's title fits on one line again ("Alchemy 75/150"; the logo says Craftbound).
- Screenshots in the docs, the README and on the CurseForge page (the trainer panel and the
  auction house too).
- The merchant's **Buy route reagents** button sits just above the vendor window, on the right:
  below it, the tab row covered it.
- The profession panel's footer no longer says to go to the auction house when you have every
  reagent.

### 0.2.2-alpha (2026-11-22)

- First version on CurseForge.
- **Waypoints** (`/craft way`, or the map button on the profession panel and the tracker): to the
  nearest trainer for your next rank or recipe, the recipe's vendor, or a vendor selling a
  reagent you're missing, on your side and continent. Map waypoint plus TomTom. Trainer and
  vendor places come from QuestieDB (Questie, GPLv3); Craftbound is now GPL-3.0-or-later.
- **At the trainer**: a panel beside the profession trainer lists what the route needs from it,
  up to your stop (the next rank, the recipes of the steps ahead, the recipes of their parts), and
  **Train N** trains only those, not everything the trainer has.
  It reads each recipe's skill and level requirements itself, since Forever's trainer window
  doesn't always mark what you can learn, and knows Forever's rank names ("Journeyman
  Alchemist"). `/craft trainerinfo` prints what the trainer's list says, for bug reports.
- The vendor's "Buy route reagents" button sits below the vendor window on the right, no longer
  over the Merchant and Buyback tabs.
- **At a rank's cap** (75/75, 150/150, 225/225) Blizzard's Create and Create All buttons ask
  before they craft, since crafting gives no skill-up there; "Craft anyway" lets the clicks
  through until the skill or the cap changes. Craftbound's own Craft button already stopped.
  `/craft toggle cap` turns the question off.

### 0.2.1-alpha (2026-11-22)

- `/craft shots` takes screenshots of every Craftbound frame for the docs (the window, the
  editor, the export box, the tracker, and the profession window it opens itself; the auction
  house panel when the auction house is open).
- Releases are packed and published by GitHub Actions when a version is tagged.

### 0.2.0-alpha (2026-11-22)

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

### 0.1.0-alpha (2026-11-22)

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
<!-- changelog:end -->
