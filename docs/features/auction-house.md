---
title: Auction house
parent: Features
nav_order: 2
description: The shopping list, price scans, Buy and Confirm, and merchants.
---

# Auction house

Open the auction house and the **Craftbound shopping** panel docks to its right. It lists every reagent the rest of the route still needs, minus what is in your bags and bank, with the most-missing first.

## Buying

The big button at the bottom always does the next sensible thing:

1. **Scan prices.** Searches each missing reagent, one after another, and fills in the price column. The cost is worked out for the amount you need, cheapest auctions first. A red `*` means there isn't enough on sale.
2. **Buy 90 Peacebloom (~2g 10s).** Asks the server for the exact price of that amount.
3. **Confirm 2g 3s.** Buys it. If the price is more than 25% above the scan, a red warning shows first. If you don't have enough money, nothing happens.

Then it moves on to the next reagent. What you buy goes to your mailbox, and Craftbound counts it as yours straight away, so it isn't offered again. When you open the mailbox, it counts what is really there. **Cancel** drops a purchase you haven't confirmed. **Rescan** throws away the prices and scans again.

Reagents that come in stacks (herbs, dust, essences) are bought as commodities: the server picks the cheapest for you. Single items (rods, pearls) are bought one auction at a time, and the button shows that auction's buyout.

## The list

- **Click** a row to search for it in Blizzard's own auction house window, if you would rather buy it by hand.
- **Shift-click** a row to scan that item again.
- **Hover** a row for the route's total need, what you have, the cheapest price and how many are on sale.
- Vials and the Copper Rod say **vendor**: they cost a few copper at a merchant, so Craftbound never buys them at the auction house.

## Merchants

When a merchant sells something the route needs, a **Buy route reagents (cost)** button appears below its window, on the right (the Merchant and Buyback tabs are on the left). One click buys everything still missing, in full stacks. Items in limited stock are bought as far as the merchant's stock goes. Come back later for the rest.

## Turning it off

`/craft toggle shop` hides the shopping panel.
