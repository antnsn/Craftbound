# Changelog

## Unreleased

- Marius' painted icon: in the addon list, on a new minimap button (left-click: tracker,
  right-click: pick a guide, drag to move; collected by minimap addons through LibDBIcon when
  one is loaded), beside the panel titles and as the docs logo.
- Three new guides: Blacksmithing (125-300), Engineering and Leatherworking (1-300).
- Steps can need several tools (hammer, spanner, micro-adjustor) and a station (anvil,
  forge, tanning rack, sewing machine). A bought tool (the Blacksmith Hammer) is its own step,
  shopped for and bought at the merchant.
- Parts made along the way (grinding stones, power cores, cured hides): the shopping list buys
  their reagents, and **Craft** makes the parts before the step that needs them.
- Recipe notes name the reputation they need.
- The guide picker is wider, so long lines (Blacksmithing 125-300, active) fit; button labels are
  cut off inside the button instead of spilling past it.
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
