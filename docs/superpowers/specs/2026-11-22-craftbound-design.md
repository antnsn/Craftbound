# Craftbound: design

Date: 2026-11-22. Author: Claude, working on its own overnight at Marius's request ("brainstorm, do the
whole job, push, make a wiki like Chronobound's").

## Intent

Levelling a profession from 1 to 300 on WoW: Forever is a long, boring chore: read a guide in a
browser, work out what to buy, search the auction house item by item, find the recipe in the window,
click Create over and over, and forget where you were the next evening. Craftbound does that chore
for you. It knows the route, knows what you already have, does the shopping in the auction house,
puts the right recipe in front of you in the profession window and remembers, per character,
exactly where you stopped.

Forever only (Interface 16001, Lua 5.1, the modern `C_TradeSkillUI` / `C_AuctionHouse` API).
No Classic Era, no retail branches.

## Goals

- **The next thing to do, always.** One line: "Craft *Enchant Bracer - Lesser Stamina* ~22 more
  (skill 142 → 164)", or "Train Expert at a trainer", or "Make a Runed Silver Rod and keep it".
- **Profession window integration.** A panel docked to the profession window: current step,
  skill-up colour, progress, the recipe selected for you, a **Craft** button that crafts as many as
  the step still needs (capped by what you can make), alternatives when the main recipe isn't known
  or you lack reagents.
- **Auction house integration.** A panel docked to the auction house: the shopping list for the rest
  of the route minus what you have in bags and bank, a **Buy next** flow that searches the next item,
  shows the total price, and buys the missing quantity on a second click. Search buttons per item.
- **Character persistent, resumable.** Per-character saved state: active guide, the step you are on,
  steps you ticked by hand (disenchanting, tools, ranks), skill history. On login a small tracker
  says where you left off; `/craft` reopens it.
- **Two guides** from `profession-guides.json`: *Enchanting: Easiest* and *Alchemy: Easiest*, 1-300.
- **Honest about data.** Forever changed recipe levels; the guide's numbers are estimates. Live
  data wins: once a recipe has been seen in the profession window its real reagents and skill-up
  colour are used and remembered (account-wide), and the guide's numbers are the fallback.

## Non-goals (v1)

- Other professions and other routes (the data format allows them; adding is a data change).
- Price analytics, profit finding, selling, posting auctions (TSM/Auctionator do that).
- Waypoints/arrows to trainers and vendors (LibTravels could do it later).
- Any non-Forever client.

## Anti-goals

- Buying something the player did not confirm. Every purchase is a click on a button that shows
  item, quantity and total price first.
- Fighting the Blizzard UI: no replacing ProfessionsFrame or the auction house, only docked panels.
- Taint: nothing touches secure frames; crafting and buying are plain button clicks (hardware events).

## Approaches considered

1. **Standalone addon, own small UI kit (chosen).** Docked panels plus a tracker, no dependencies.
   Fits a profession addon that every class uses; quick to test in wowbench.
2. **Build on LibBound.** Same look as the Bound class addons, but LibBound is class-centred
   (cards, buffs, painted per-class skins needing art). Too heavy for this and would couple a
   profession addon to class-addon releases.
3. **Plug into TSM/Auctionator** (export a shopping list to Auctionator). Cheap, but makes the AH
   half depend on another addon and loses the one-click "buy what this route still needs". An
   Auctionator list export stays possible later.

## How it works

Files (load order): `Core.lua` (namespace, saved variables, events, slash), `Guides.lua`
(generated from `profession-guides.json` by `tools/build_guides.py`, with item IDs), `Planner.lua`
(pure logic: current step, crafts left, shopping list, training due), `Inventory.lua` (bags, bank
cache per character), `Profession.lua` (C_TradeSkillUI adapter and the docked panel),
`AuctionHouse.lua` (C_AuctionHouse adapter and the docked panel), `Tracker.lua` (movable resume
tracker), `UI.lua` (small widget kit).

- **Current skill**: from the open profession (`C_TradeSkillUI.GetProfessionInfoBySkillLineID` /
  base profession info) and, closed, from `GetProfessions` + `GetProfessionInfo`. Saved per
  character so the tracker works anywhere.
- **Current step**: the first unfinished step in route order. Craft steps finish when skill ≥ `to`;
  tools when the tool is in bags (or ticked); ranks when the max skill exceeds the rank's cap (or
  ticked); disenchanting when skill ≥ `to`.
- **Crafts left in a step**: `safe × (to − skill)/(to − from)`, rounded up; a live estimate from the
  recipe's colour could refine it later.
- **Shopping list**: per material, the rest of the route's need (current step scaled, later steps
  full, tools not yet made) minus bags + bank (+ already-crafted intermediates ignored). Live reagents
  replace guide reagents once known.
- **AH buying**: search by item ID (`C_AuctionHouse.MakeItemKey`); commodities through
  `StartCommoditiesPurchase` → price → `ConfirmCommoditiesPurchase` on the confirm click; items
  (non-stackables) by cheapest `PlaceBid` buyout. Unknown item IDs are found by name through a
  browse query and cached account-wide.
- **Saved variables**: `CraftboundDB` (account: settings, item ID cache, live recipe cache) and
  `CraftboundCharDB` (per character: active guide, per-guide progress, ticks, history, bank counts).

## Left to the builder

Exact layout, wording, colours; exact API details confirmed against the Forever API dump in
`~/code/wowbench/api/client.txt` and the installed Forever addons.
