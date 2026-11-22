# Craftbound window: design

Date: 2026-11-22. Bead: Craftbound-naf.

## Why

Marius: "the addon needs a GUI, and people should be able to make and share their own guides.
The default ones stay, but the user can make their own, export and share." Also: "the user can
say they want to stop at 150, 225 or 300 in the menu", and "it would be nice if pricing could say
something about the price to 150, 225 and 300".

Today there is a panel beside the profession window, one beside the auction house, a tracker and
a plain guide picker. Guides are generated into `Guides.lua` and cannot be changed in game.

## Goals

- One Craftbound window (`/craft`, minimap left-click) to browse every guide, built-in and custom.
- Per character and guide, a **stop target**: 150, 225, 300 (those inside the guide's range) or
  the guide's end. The route, the shopping list, the progress bar and "finished" all follow it.
- **Cost to each target**, from where the character is now: missing reagents times remembered
  prices, plus recipe costs still ahead. Unpriced items and the age of prices are shown, never
  hidden.
- **Custom guides**: copy any guide and edit it; start a new one from the open profession window;
  rename, change step ranges and crafts, reorder, delete steps, add recipes from the open window.
- **Share** as a text string (copy out of a box, paste into a box): addons cannot use files or
  the clipboard. Imported guides become custom guides.

## Non-goals

- In-game sharing over addon messages (later, if wanted).
- Editing built-in guides in place (copy first).
- Exact skill-up thresholds for new steps: the client API does not expose them. New steps get an
  estimated crafts count that the author can change; recipes copied from built-in guides keep
  their thresholds.

## Anti-goals

- A cost that looks certain but is not (stale or missing prices without saying so).
- Running anything from an imported string: the format is parsed as data only, then sanitised
  field by field (types, lengths, counts), never `loadstring`.

## Approaches considered

1. **Main window with list + details + editor pane (chosen).** One place for everything; fits
   the existing UI kit (plain frames, pools, mouse-wheel lists).
2. Extend the existing picker and add separate editor/import dialogs: less code at first, but
   three small windows that do not know about each other.
3. Blizzard settings panel (Settings API): good for toggles, poor for lists and editors.

## Decisions (Claude's calls; Marius handed over the how)

- `/craft` opens the window; the tracker moves to `/craft tracker`. Minimap: left-click window,
  right-click tracker. The old guide picker is replaced by the window.
- Target stored as `CraftboundCharDB.guides[key].target`; the planner takes `ctx.target`. Steps
  starting at or above the target are out of scope; a step crossing it is cut and its crafts
  scaled; a rank needed only past the target is skipped; a tool no in-scope step needs is skipped.
  Step indices never change (ticks stay valid).
- Prices: `CraftboundDB.prices[itemID] = { unit, at }` from Craftbound's AH scans; then
  Auctionator (`Auctionator.API.v1.GetAuctionPriceByItemID`, age from `GetAuctionAgeByItemID`)
  when installed; vendor buy prices from the imported Wowhead catalogs and from merchants seen.
- Custom guides live in `CraftboundDB.custom` (account-wide), keyed `custom:<n>`, registered into
  `ns.Guides` at load so every panel works with them unchanged.
- Share string: `CB1:` + base64 of a small restricted serializer (tables, strings, numbers,
  booleans). Import validates against a whitelist of guide and step fields, caps 300 steps,
  60 reagents per step, 120-character strings.
- New steps: from = previous step's end, to = from + 10, crafts = ceil(1.3 per point); reagents
  read from the recipe schematic.

## Left to the builder

Layout details, wording, row counts.
