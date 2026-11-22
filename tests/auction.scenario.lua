-- The auction house: scan prices, buy the most-missing reagent in two clicks, vendor items
-- stay out of it, and merchants sell the vials.
local T = dofile(wb.dir .. "/tests/_helper.lua")
wb.state.player.level = 30
wb.state.player.money = 10000000

wb.login({ saved = T.professionGlobals({ [T.ALCHEMY] = { name = "Alchemy", rank = 1, max = 75 } }) })
-- what the Alchemy route needs from 1, from the guide itself
local guide = wb.ns.Planner.Find("Alchemy:Tried & Tested")
local function need(name)
	local n = 0
	for _, st in ipairs(guide.steps) do
		for _, m in ipairs(st.mats or {}) do if m.name == name then n = n + st.safe * m.qty end end
	end
	return n
end
local PB, VIALS = need("Peacebloom"), need("Empty Vial")
local COST = 30 * 20 + (PB - 30) * 25
local market = {
	[2447] = { { 20, 30 }, { 25, 200 } },   -- Peacebloom
	[765] = { { 40, 100 } },                -- Silverleaf
}
local ah = T.auctionHouse(market)
T.inject({ C_AuctionHouse = ah, Enum = { AuctionHouseSortOrder = { Price = 0 }, AuctionHouseFilter = { ExactMatch = 1 } } })
wb.G.CreateFrame("Frame", "AuctionHouseFrame", wb.G.UIParent):Show()

wb.fire("AUCTION_HOUSE_SHOW")
wb.advance(0.2)
wb.check(wb.shown("CraftboundAuctionPanel"), "shopping panel docked")
wb.expect("first press scans", wb.ns.AH.Plan().label, "Scan prices")
wb.ns.AH.Press()
wb.advance(0.1)
-- answer each search the addon sends
for _ = 1, 40 do
	local id = ah.calls.search[#ah.calls.search]
	if id and not wb.ns.AH.prices[id] then
		wb.fire("COMMODITY_SEARCH_RESULTS_UPDATED", id)
	end
	wb.advance(0.3)
	if not wb.ns.AH.scanning and #ah.calls.search > 0 then break end
end
for _, id in ipairs(ah.calls.search) do
	wb.check(id ~= 3371 and id ~= 3372 and id ~= 8925, "vials are never searched: " .. id)
end
local pb = wb.ns.AH.prices[2447]
wb.check(pb and pb.commodity, "peacebloom priced")
wb.expect("cost walks the cheapest first", pb.cost, COST)

-- buy: the most-missing priced item first
local plan = wb.ns.AH.Plan()
wb.check(plan.label:find("Buy " .. PB .. " Peacebloom"), "buys peacebloom: " .. plan.label)
wb.ns.AH.Press()
wb.expect("purchase started", ah.calls.start[1] and ah.calls.start[1].qty, PB)
wb.expect("nothing confirmed yet", #ah.calls.confirm, 0)
wb.fire("COMMODITY_PRICE_UPDATED", math.floor(COST / PB), COST)
plan = wb.ns.AH.Plan()
wb.check(plan.label:find("Confirm"), "second click confirms: " .. plan.label)
wb.ns.AH.Press()
wb.expect("confirmed with the same quantity", ah.calls.confirm[1] and ah.calls.confirm[1].qty, PB)
wb.fire("COMMODITY_PURCHASE_SUCCEEDED")
wb.advance(1)
local function missingOf(name)
	for _, e in ipairs((wb.ns.AH.List())) do if e.name == name then return e.missing end end
end
wb.expect("bought peacebloom counts while in the mailbox", missingOf("Peacebloom"), 0)
wb.check(not wb.ns.AH.Plan().label:find("Peacebloom"), "doesn't offer peacebloom again")

-- the mailbox: collect it (mail empty, bags full)
T.inject({ GetInboxNumItems = function() return 0 end, GetInboxItem = function() end })
wb.state.bags[2447] = PB
wb.fire("MAIL_INBOX_UPDATE")
wb.expect("mail recounted", wb.saved("CraftboundCharDB").mail[2447], nil)
wb.expect("still covered from bags", missingOf("Peacebloom"), 0)

-- toggling the shop panel off and on while the auction house is open
wb.slash("/craft toggle shop")
wb.check(not wb.shown("CraftboundAuctionPanel"), "shop panel hidden")
wb.slash("/craft toggle shop")
wb.check(wb.shown("CraftboundAuctionPanel"), "shop panel back")

-- a price jump is shown before the confirm
wb.ns.AH.prices[765] = { commodity = true, rows = { { unit = 40, quantity = 100 } }, avail = 100, unit = 40, cost = 2000, short = 0 }
plan = wb.ns.AH.Plan()
wb.ns.AH.Press()
wb.fire("COMMODITY_PRICE_UPDATED", 400, 20000)
wb.check(wb.ns.AH.Plan().warn, "price jump warned")
wb.ns.AH.Cancel()
wb.expect("cancel tells the server", ah.calls.cancel, 1)
wb.fire("AUCTION_HOUSE_CLOSED")

-- merchant sells vials
local bought = {}
T.inject({
	GetMerchantNumItems = function() return 2 end,
	GetMerchantItemID = function(i) return i == 1 and 3371 or 159 end,
	GetMerchantItemMaxStack = function() return 20 end,
	BuyMerchantItem = function(i, n) bought[#bought + 1] = { i = i, n = n } end,
	C_MerchantFrame = { GetItemInfo = function() return { price = 4, stackCount = 1, numAvailable = -1, isPurchasable = true } end },
})
wb.G.CreateFrame("Frame", "MerchantFrame", wb.G.UIParent):Show()
wb.fire("MERCHANT_SHOW")
local total = 0
for _, b in ipairs(bought) do total = total + b.n end
wb.expect("nothing bought before the click", total, 0)
local btn
for _, f in ipairs(wb.frames()) do
	if f.__text and tostring(f.__text):find("Buy route reagents") then btn = f end
end
wb.check(btn, "merchant button shown")
btn.__scripts.OnClick(btn)
for _, b in ipairs(bought) do total = total + b.n end
wb.expect("all empty vials bought in stacks of 20", total, VIALS)

-- the total covers every missing item, not only the rows that fit
wb.fire("AUCTION_HOUSE_SHOW")
local panel = wb.frame("CraftboundAuctionPanel")
panel:SetHeight(250) -- room for 5 rows
wb.ns.AH.prices = {}
local want = 0
for _, e in ipairs((wb.ns.AH.List())) do
	local id = wb.ns.ItemID(e)
	if e.missing > 0 and id and not wb.ns.AH.VENDOR_ITEMS[id] then
		wb.ns.AH.prices[id] = { commodity = true, rows = { { unit = 1, quantity = 9999 } }, avail = 9999, unit = 1, cost = e.missing, short = 0 }
		want = want + e.missing
	end
end
wb.ns.Fire("CB_REFRESH")
wb.check(tostring(panel.total.__text):find(tostring(want % 100) .. "|cffeda55fc"), "total over the whole list: " .. tostring(panel.total.__text) .. " want " .. want)
wb.check(tostring(panel.more.__text):find("of"), "says there is more to scroll")

-- a partly loaded inbox keeps purchases it can't see yet
wb.ns.AddMail(765, 50)
T.inject({ GetInboxNumItems = function() return 0, 60 end })
wb.fire("MAIL_INBOX_UPDATE")
wb.expect("unloaded mail kept", wb.saved("CraftboundCharDB").mail[765], 50)

-- cached prices follow what is missing now
local p = { rows = { { unit = 10, quantity = 5 }, { unit = 20, quantity = 100 } } }
local c, s = wb.ns.AH.CostNow(p, 7)
wb.expect("cost for 7", c, 5 * 10 + 2 * 20)
wb.expect("no shortfall", s, 0)

-- collecting mail while only part of the inbox is loaded
wb.state.bags[765] = 0
wb.fire("MAIL_SHOW")
wb.state.bags[765] = 20
wb.fire("BAG_UPDATE_DELAYED")
wb.expect("collected attachments leave the mail count", wb.saved("CraftboundCharDB").mail[765], 30)
wb.fire("MAIL_CLOSED")

-- item auctions cost whole listings
local items = { commodity = false, rows = { { unit = 10, quantity = 10, buyout = 100 } } }
wb.expect("one from a stack of ten costs the stack", (wb.ns.AH.CostNow(items, 1)), 100)

-- a quote never confirmed is not credited by someone else's purchase
wb.fire("AUCTION_HOUSE_SHOW")
local before = wb.saved("CraftboundCharDB").mail[765] or 0
wb.ns.AH.prices[765] = { commodity = true, rows = { { unit = 40, quantity = 100 } }, avail = 100, unit = 40 }
wb.ns.AH.Press()                      -- Buy (quote requested)
wb.fire("AUCTION_HOUSE_PURCHASE_COMPLETED", 777) -- a buy made by hand
wb.expect("hand purchase not credited", wb.saved("CraftboundCharDB").mail[765] or 0, before)
