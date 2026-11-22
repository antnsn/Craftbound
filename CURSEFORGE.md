<!-- summary (CurseForge "Summary" field, at most 256 characters):
Profession levelling for WoW: Forever: tested routes for eight professions, the next step and a Craft button beside the profession window, an auction house shopping list, where to stop and what it costs, and your own guides to share.
-->

# Craftbound

**Profession levelling for World of Warcraft: Forever, as close to automatic as the game allows.**

Craftbound follows a levelling route for you. Beside the profession window it shows the next step and crafts it with one button or key. At the auction house it shops for the rest of the route, and at vendors it buys what vendors sell. It remembers per character where you stopped, so you pick up right there.

**Full guide:** https://antnsn.github.io/Craftbound/

**Alpha:** Craftbound is new and not yet tested much in game. Tell us what doesn't work.

## Guides
- **Eight professions, 1-300**: Enchanting, Alchemy, Blacksmithing, Engineering, Leatherworking, Tailoring, Cooking and First Aid. The routes are Wowhead's "Tried & Tested in Forever", with Forever's own recipes, vendors, stations and reputation.
- **Follows your real skill**: a step ends when your skill reaches its end, however many crafts that took.
- **Tools, stations and parts**: runed rods, hammers and spanners stay on the route until the last step that needs them; the step says where to craft (anvil, loom, oven); grinding stones, bolts, cured hides and blasting powder are made along the way, and **Craft** makes them first.
- **Real reagents**: once you open a recipe, Craftbound uses the game's reagents, even if Forever changed them.

## The profession window
- **A panel beside it**: the step, its skill-up colour, the reagents you have and need, and the route ahead.
- **Craft** (button or key binding) crafts the step: as many as you can, never past your rank's cap. Enchants go on the right equipped item.
- **Says what's missing**: a recipe to learn (and where, from the vendors of your faction), a rank to train, a tool to make.

## The auction house and vendors
- **A shopping list** of what the rest of the route needs, minus what's in your bags, bank and mailbox.
- **Buy** the most-needed item in two clicks at the server's price, with a warning when the price jumped.
- **Vendor goods never at the auction house**: vials, thread, dye, flux and spices are bought at a merchant with one click.

## The Craftbound window
- **Every guide** in one place (`/craft` or the minimap button), with its route and your skill.
- **Stop at 150, 225 or 300**: the route, the shopping list and the progress bar end there.
- **What each stop costs** from where you are: missing reagents at remembered prices (your scans, Auctionator's database when you have it, vendor prices) plus recipes still to learn. Missing and old prices are said, never hidden.

## Your own guides
- **Copy and edit** any guide: name, skill ranges, crafts, order, steps.
- **New guide**: with your profession window open, click recipes to add them.
- **Share**: Export gives a text you paste anywhere; Import turns someone's text into one of your guides. It is read as data only, never run.

## Also in it
- **Per character**: progress, skills and history are kept per character; your own guides and remembered prices are shared by the account.
- **Tracker**: a small box that says where you left off, anywhere in the world.
- **Minimap button** (works with minimap addons through LibDBIcon) and an addon compartment entry.

## Commands
- `/craft`: open the Craftbound window
- `/craft tracker`: show or hide the tracker
- `/craft guide enchanting`: follow a profession's guide
- `/craft stop 150`: stop at 150 (or 225, 300; `end` for the guide's end)
- `/craft list`: the shopping list in chat
- `/craft tick`, `/craft untick 3`: tick off a step by hand, or put it back
- `/craft reset`: forget this character's progress in the active guide
- `/craft toggle panel|shop|select|tracker|minimap`: turn a part on or off
- `/craft help`: list every command

Key bindings (Key Bindings > AddOns > Craftbound): **Craft the next step** and **Auction house: buy next / confirm**.

## Ideas and contributions
- **Missing something?** New features are added on request: leave a comment here.
- **Feel free to contribute**: the code is on GitHub, https://github.com/antnsn/Craftbound (issues and pull requests welcome).

## Changelog
<!-- changelog:start -->
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
