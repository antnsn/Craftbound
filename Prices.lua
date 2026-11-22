-- Prices: what an item costs, remembered across sessions, and the cost of a route to a target.
--
-- Sources, best first:
--   vendor      buy prices from the imported catalogs (ns.VendorPrices) and from merchants seen
--   scan        Craftbound's own auction house scans (CraftboundDB.prices), with their age
--   Auctionator its price database, when that addon is installed
local _, ns = ...

local Prices = {}
ns.Prices = Prices

local DAY = 86400

-- A scan found this unit price (copper) for an item.
function Prices.Remember(itemID, unit)
	if itemID and unit and unit > 0 then ns.db.prices[itemID] = { unit = unit, at = time() } end
end

local function auctionator(itemID)
	local A = rawget(_G, "Auctionator")
	local api = A and A.API and A.API.v1
	if not (api and api.GetAuctionPriceByItemID) then return nil end
	local ok, price = pcall(api.GetAuctionPriceByItemID, "Craftbound", itemID)
	if not ok or type(price) ~= "number" or price <= 0 then return nil end
	local days
	if api.GetAuctionAgeByItemID then
		local ok2, d = pcall(api.GetAuctionAgeByItemID, "Craftbound", itemID)
		if ok2 and type(d) == "number" then days = d end
	end
	return price, days
end

-- Unit price of a material ({ id, name }): copper, source ("vendor", "scan", "auctionator"),
-- age in seconds (nil when unknown or for vendors). nil when nothing knows a price.
function Prices.Unit(mat)
	local id = ns.ItemID(mat)
	if not id then return nil end
	local v = ns.db.vendorPrices[id] or (ns.VendorPrices and ns.VendorPrices[id])
	if v then return v, "vendor" end
	local scan = ns.db.prices[id]
	local a, aDays = auctionator(id)
	-- the newer of our scan and Auctionator's (Auctionator counts whole days: same day, ours wins)
	if scan and (not a or not aDays or math.floor((time() - scan.at) / DAY) <= aDays) then
		return scan.unit, "scan", time() - scan.at
	end
	if a then return a, "auctionator", aDays and aDays * DAY end
	if scan then return scan.unit, "scan", time() - scan.at end
	return nil
end

-- What the route costs from where the character is now to a target skill:
-- { copper, recipes (copper, included), unpriced (items without a price), oldest (seconds),
--   sources = { scan = n, auctionator = n, vendor = n }, missing (pieces) }
function Prices.CostTo(guide, target)
	local ctx = ns.Context(guide)
	ctx.target = target
	local list = ns.Planner.Shopping(guide, ctx)
	local out = { copper = 0, unpriced = 0, sources = {}, missing = 0 }
	for _, e in ipairs(list) do
		if e.missing > 0 then
			out.missing = out.missing + e.missing
			local unit, src, age = Prices.Unit(e)
			if unit then
				out.copper = out.copper + unit * e.missing
				out.sources[src] = (out.sources[src] or 0) + 1
				if age and (not out.oldest or age > out.oldest) then out.oldest = age end
			else
				out.unpriced = out.unpriced + 1
			end
		end
	end
	out.recipes = ns.Planner.RecipeCost(guide, ctx)
	out.copper = out.copper + out.recipes
	return out
end

-- "3 days", "5 hours", "12 min"
function Prices.Age(seconds)
	if not seconds then return nil end
	if seconds >= 2 * DAY then return ("%d days"):format(seconds / DAY) end
	if seconds >= 7200 then return ("%d hours"):format(seconds / 3600) end
	return ("%d min"):format(math.max(1, seconds / 60))
end

-- One line under a cost: where the prices come from and what is missing.
function Prices.Describe(c)
	local bits = {}
	local s = c.sources
	if s.scan then bits[#bits + 1] = "your scans" end
	if s.auctionator then bits[#bits + 1] = "Auctionator" end
	if s.vendor then bits[#bits + 1] = "vendors" end
	local line = #bits > 0 and ("Prices from " .. table.concat(bits, ", ")) or "No prices yet"
	if c.oldest and c.oldest > 6 * 3600 then line = line .. (", up to %s old"):format(Prices.Age(c.oldest)) end
	if c.unpriced > 0 then
		line = line .. (" · %d item%s without a price (scan at the auction house)"):format(c.unpriced, c.unpriced == 1 and "" or "s")
	end
	return line
end

-- Merchants: remember the buy price of every item they sell that a guide uses.
ns.On("MERCHANT_SHOW", function()
	if not (GetMerchantNumItems and C_MerchantFrame and C_MerchantFrame.GetItemInfo) then return end
	for i = 1, GetMerchantNumItems() or 0 do
		local id = GetMerchantItemID and GetMerchantItemID(i)
		local ok, info = pcall(C_MerchantFrame.GetItemInfo, i)
		if id and ok and type(info) == "table" and type(info.price) == "number" and info.price > 0
			and not info.hasExtendedCost then
			local per = info.price / math.max(1, info.stackCount or 1)
			if ns.UsedIDs[id] or (ns.AH and ns.AH.VENDOR_ITEMS[id]) then ns.db.vendorPrices[id] = per end
		end
	end
end)
