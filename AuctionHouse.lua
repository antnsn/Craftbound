-- AuctionHouse: shops the rest of the route in Blizzard's auction house (C_AuctionHouse), and
-- buys vendor reagents (vials, rods, flux, thread, dye, the hammer) at merchants.
--
-- Nothing is bought without a click that shows what and for how much:
--   commodities  Buy → StartCommoditiesPurchase → the server's price → Confirm (second click)
--   items        the button shows the cheapest buyout; the click is the PlaceBid
-- The "Auction house: buy next / confirm" key binding presses the same button.
local _, ns = ...

local UI = ns.UI
local P = ns.Planner
local AH = {}
ns.AH = AH

-- Sold by vendors for a few copper: never worth the auction house.
local VENDOR_ITEMS = {
	[3371] = true, -- Empty Vial
	[3372] = true, -- Leaded Vial
	[8925] = true, -- Crystal Vial
	[6217] = true, -- Copper Rod
	[5956] = true, -- Blacksmith Hammer
	[2880] = true, [3466] = true, -- Weak Flux, Strong Flux
	[2320] = true, [2321] = true, [4291] = true, [8343] = true, [14341] = true, -- threads
	[4289] = true, -- Salt
	[2605] = true, [4340] = true, [2325] = true, -- Green, Gray, Black Dye
}
for id in pairs(ns.GuideVendorItems or {}) do VENDOR_ITEMS[id] = true end
AH.VENDOR_ITEMS = VENDOR_ITEMS

AH.prices = {}   -- [itemID] = { commodity, unit, avail, cost, short, auctions, at }
AH.status = ""
local queue, busy, waiting = {}, nil, nil
local buying     -- { itemID, qty, total, name, commodity, auctionID, buyout, confirm }
local isOpen = false

local function sorts()
	local order = Enum and Enum.AuctionHouseSortOrder and Enum.AuctionHouseSortOrder.Price or 0
	return { { sortOrder = order, reverseSort = false } }
end

local function setStatus(text)
	AH.status = text or ""
	ns.Refresh()
end

-- The shopping list right now: what's missing, with prices where scanned.
function AH.List()
	local guide = ns.ActiveGuide()
	if not guide then return {}, 0, guide end
	local list, missing = P.Shopping(guide, ns.Context(guide))
	return list, missing, guide
end

-- Cheapest way to buy qty from sorted results: returns cost, how many could be bought.
local function walk(rows, qty)
	local cost, got = 0, 0
	for _, r in ipairs(rows) do
		if got >= qty then break end
		local take = math.min(r.quantity, qty - got)
		cost = cost + take * r.unit
		got = got + take
	end
	return cost, got
end
AH.Walk = walk

-- Item auctions are bought whole: cost of the cheapest listings that cover qty.
local function walkWhole(rows, qty)
	local cost, got = 0, 0
	for _, r in ipairs(rows) do
		if got >= qty then break end
		cost = cost + (r.buyout or r.unit * r.quantity)
		got = got + r.quantity
	end
	return cost, got
end

local function readCommodity(itemID)
	local rows, avail = {}, 0
	local n = C_AuctionHouse.GetNumCommoditySearchResults(itemID) or 0
	for i = 1, n do
		local r = C_AuctionHouse.GetCommoditySearchResultInfo(itemID, i)
		if r and r.unitPrice then
			local q = (r.quantity or 0) - (r.numOwnerItems or 0)
			if q > 0 then
				rows[#rows + 1] = { unit = r.unitPrice, quantity = q }
				avail = avail + q
			end
		end
	end
	table.sort(rows, function(a, b) return a.unit < b.unit end)
	return rows, avail
end

local function readItems(itemKey)
	local rows, avail = {}, 0
	local n = C_AuctionHouse.GetNumItemSearchResults(itemKey) or 0
	for i = 1, n do
		local r = C_AuctionHouse.GetItemSearchResultInfo(itemKey, i)
		if r and r.buyoutAmount and r.buyoutAmount > 0 and not r.containsOwnerItem then
			local q = r.quantity or 1
			rows[#rows + 1] = { unit = r.buyoutAmount / q, quantity = q, auctionID = r.auctionID, buyout = r.buyoutAmount }
			avail = avail + q
		end
	end
	table.sort(rows, function(a, b) return a.unit < b.unit end)
	return rows, avail
end

-- Store what a search found for an item, priced for what's still missing.
local function record(itemID, commodity, rows, avail)
	local missing = 0
	for _, e in ipairs((AH.List())) do
		if ns.ItemID(e) == itemID then missing = e.missing end
	end
	local cost, got = (commodity and walk or walkWhole)(rows, missing)
	AH.prices[itemID] = {
		commodity = commodity, rows = rows, avail = avail,
		unit = rows[1] and rows[1].unit, cost = cost, short = math.max(0, missing - got), at = GetTime(),
	}
	if rows[1] then ns.Prices.Remember(itemID, rows[1].unit) end
	ns.Refresh()
end

-- Cost and shortfall of an item's cached offers for the quantity missing now.
local function costNow(p, missing)
	if not p or not p.rows then return 0, missing end
	local cost, got = (p.commodity == false and walkWhole or walk)(p.rows, missing)
	return cost, math.max(0, missing - got)
end
AH.CostNow = costNow

-- Search queue ----------------------------------------------------------------------------

local function nextSearch()
	if busy or not isOpen then return end
	local job = table.remove(queue, 1)
	if not job then
		if AH.scanning then
			AH.scanning = nil
			setStatus("Prices scanned.")
		end
		return
	end
	if C_AuctionHouse.IsThrottledMessageSystemReady and not C_AuctionHouse.IsThrottledMessageSystemReady() then
		table.insert(queue, 1, job)
		C_Timer.After(0.5, nextSearch)
		return
	end
	busy = job
	local token = {}
	waiting = token
	if job.itemID then
		job.key = C_AuctionHouse.MakeItemKey(job.itemID)
		C_AuctionHouse.SendSearchQuery(job.key, sorts(), true)
	else
		local filters = Enum and Enum.AuctionHouseFilter and { Enum.AuctionHouseFilter.ExactMatch } or {}
		C_AuctionHouse.SendBrowseQuery({ searchString = job.name, sorts = sorts(), filters = filters })
	end
	C_Timer.After(6, function()
		if waiting == token then
			if job.itemID then AH.prices[job.itemID] = { none = true, at = GetTime() } end
			busy, waiting = nil, nil
			ns.Refresh()
			nextSearch()
		end
	end)
end

local function finish()
	busy, waiting = nil, nil
	C_Timer.After(0.15, nextSearch)
end

function AH.Search(entry, front)
	local id = ns.ItemID(entry)
	local job = { itemID = id, name = entry.name }
	if front then table.insert(queue, 1, job) else queue[#queue + 1] = job end
	nextSearch()
end

function AH.ScanAll()
	local list = AH.List()
	local n = 0
	for _, e in ipairs(list) do
		local id = ns.ItemID(e)
		if e.missing > 0 and not (id and VENDOR_ITEMS[id]) then
			AH.Search(e)
			n = n + 1
		end
	end
	if n > 0 then
		AH.scanning = true
		setStatus(("Scanning %d items..."):format(n))
	end
end

ns.On("COMMODITY_SEARCH_RESULTS_UPDATED", function(itemID)
	if C_AuctionHouse.HasFullCommoditySearchResults and not C_AuctionHouse.HasFullCommoditySearchResults(itemID) then
		C_AuctionHouse.RequestMoreCommoditySearchResults(itemID)
		return
	end
	local rows, avail = readCommodity(itemID)
	record(itemID, true, rows, avail)
	if busy and busy.itemID == itemID then finish() end
end)

ns.On("ITEM_SEARCH_RESULTS_UPDATED", function(itemKey)
	local itemID = itemKey and itemKey.itemID
	if not itemID then return end
	if C_AuctionHouse.HasFullItemSearchResults and not C_AuctionHouse.HasFullItemSearchResults(itemKey) then
		C_AuctionHouse.RequestMoreItemSearchResults(itemKey)
		return
	end
	local rows, avail = readItems(itemKey)
	record(itemID, false, rows, avail)
	if busy and busy.itemID == itemID then finish() end
end)

ns.On("AUCTION_HOUSE_BROWSE_RESULTS_UPDATED", function()
	if not busy or busy.itemID then return end
	local want = busy.name
	for _, r in ipairs(C_AuctionHouse.GetBrowseResults() or {}) do
		local id = r.itemKey and r.itemKey.itemID
		local name = id and C_Item.GetItemNameByID and C_Item.GetItemNameByID(id)
		if id and name == want then
			ns.LearnItem(want, id)
			finish()
			AH.Search({ id = id, name = want }, true)
			return
		end
	end
	setStatus(("Nobody sells %s right now."):format(want))
	finish()
end)

-- Buying --------------------------------------------------------------------------------

-- The next thing the Buy button would do: { label, enabled, run, warn }
function AH.Plan()
	if not isOpen then return { label = "Open the auction house", enabled = false } end
	if buying and buying.confirm then
		return { label = ("Confirm %s"):format(ns.Money(buying.total)), enabled = true, warn = buying.warn, run = function()
			if buying.commodity then
				C_AuctionHouse.ConfirmCommoditiesPurchase(buying.itemID, buying.qty)
				setStatus(("Buying %d %s..."):format(buying.qty, buying.name))
				buying.confirm = nil
				buying.submitted = true
			end
		end }
	end
	if buying then return { label = "Waiting for the price...", enabled = false } end
	local list, missing = AH.List()
	if missing == 0 then return { label = "You have everything", enabled = false } end
	local unscanned = false
	for _, e in ipairs(list) do
		local id = ns.ItemID(e)
		if e.missing > 0 and not (id and VENDOR_ITEMS[id]) then
			local p = id and AH.prices[id]
			if not p then
				unscanned = true
			elseif p.rows and p.rows[1] then
				local qty = math.min(e.missing, p.avail)
				if p.commodity then
					local est = walk(p.rows, qty)
					return { label = ("Buy %d %s (~%s)"):format(qty, e.name, ns.Money(est)), enabled = true, run = function()
						buying = { itemID = id, qty = qty, name = e.name, commodity = true, estimate = est }
						C_AuctionHouse.StartCommoditiesPurchase(id, qty)
						setStatus("Asking the server for the price...")
					end }
				else
					local r = p.rows[1]
					return { label = ("Buy %d %s for %s"):format(r.quantity, e.name, ns.Money(r.buyout)), enabled = true, run = function()
						buying = { itemID = id, qty = r.quantity, name = e.name, auctionID = r.auctionID, submitted = true }
						C_AuctionHouse.PlaceBid(r.auctionID, r.buyout)
						setStatus(("Buying %s..."):format(e.name))
					end }
				end
			end
		end
	end
	if unscanned then return { label = "Scan prices", enabled = true, run = AH.ScanAll } end
	return { label = "Nothing on sale that you need", enabled = false }
end

function AH.Press()
	local plan = AH.Plan()
	if plan.enabled and plan.run then plan.run() end
end
function Craftbound_BuyNext() AH.Press() end

local function cancelBuy()
	if buying and buying.submitted then return end -- already sent: wait for the result
	if buying and buying.commodity and C_AuctionHouse.CancelCommoditiesPurchase then
		C_AuctionHouse.CancelCommoditiesPurchase()
	end
	buying = nil
	ns.Refresh()
end
AH.Cancel = cancelBuy

ns.On("COMMODITY_PRICE_UPDATED", function(unitPrice, totalPrice)
	if not buying or not buying.commodity then return end
	buying.total = totalPrice or (unitPrice or 0) * buying.qty
	buying.confirm = true
	if buying.estimate and buying.estimate > 0 and buying.total > buying.estimate * 1.25 then
		buying.warn = ("Price went up: %s instead of ~%s."):format(ns.Money(buying.total), ns.Money(buying.estimate))
	end
	if GetMoney() < buying.total then
		setStatus(UI.Color({ 1, 0.4, 0.3 }, "Not enough money for that."))
		cancelBuy()
		return
	end
	setStatus(buying.warn or ("%d %s for %s. Click Confirm."):format(buying.qty, buying.name, ns.Money(buying.total)))
end)

ns.On("COMMODITY_PRICE_UNAVAILABLE", function()
	if buying then
		buying = nil
		setStatus("That price is gone. Scan again.")
	end
end)

-- Only the purchase Craftbound sent counts: not a quote never confirmed, not a buy made by
-- hand in Blizzard's window.
local function bought(kind, auctionID)
	local item = buying
	if not item or not item.submitted then return end
	if kind == "commodity" and not item.commodity then return end
	if kind == "item" and (item.commodity or (auctionID and item.auctionID and auctionID ~= item.auctionID)) then return end
	buying = nil
	do
		ns.AddMail(item.itemID, item.qty)
		setStatus(("Bought %d %s: it is in your mailbox."):format(item.qty, item.name))
		AH.prices[item.itemID] = nil
		C_Timer.After(0.5, function() AH.Search({ id = item.itemID, name = item.name }, true) end)
	end
	ns.Refresh()
end

ns.On("COMMODITY_PURCHASE_SUCCEEDED", function() bought("commodity") end)
ns.On("AUCTION_HOUSE_PURCHASE_COMPLETED", function(auctionID) bought("item", auctionID) end)
ns.On("COMMODITY_PURCHASE_FAILED", function()
	if buying then
		setStatus(("Could not buy %s. Scan again."):format(buying.name))
		AH.prices[buying.itemID] = nil
		buying = nil
	end
end)
ns.On("AUCTION_HOUSE_SHOW_ERROR", function()
	if buying then
		buying = nil
		setStatus("The auction house said no. Scan again.")
	end
end)

-- Blizzard's own search box, for buying by hand.
function AH.ShowInBlizzard(name)
	local bar = AuctionHouseFrame and AuctionHouseFrame.SearchBar
	if not bar then return end
	pcall(function()
		if bar.SearchBox and bar.SearchBox.SetText then bar.SearchBox:SetText(name) end
		if bar.StartSearch then bar:StartSearch() end
	end)
end

-- The panel ---------------------------------------------------------------------------------

local panel

local function makeRow(parent)
	local b = CreateFrame("Button", nil, parent)
	b:SetSize(284, 18)
	b.icon = b:CreateTexture(nil, "ARTWORK")
	b.icon:SetSize(16, 16)
	b.icon:SetPoint("LEFT", 2, 0)
	b.name = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	b.name:SetPoint("LEFT", 22, 0)
	b.name:SetWidth(130)
	b.name:SetJustifyH("LEFT")
	b.name:SetWordWrap(false)
	b.count = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	b.count:SetPoint("LEFT", 156, 0)
	b.count:SetWidth(50)
	b.count:SetJustifyH("RIGHT")
	b.price = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	b.price:SetPoint("RIGHT", -2, 0)
	b.price:SetJustifyH("RIGHT")
	b:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
	b:SetScript("OnClick", function(self)
		if IsShiftKeyDown() then AH.Search(self.entry, true) else AH.ShowInBlizzard(self.entry.name) end
	end)
	UI.Tooltip(b, function(tip, self)
		local e = self.entry
		tip:AddLine(e.name, 1, 1, 1)
		tip:AddDoubleLine("Rest of the route", e.need, 0.8, 0.8, 0.8, 1, 1, 1)
		tip:AddDoubleLine("You have (bags + bank)", e.have, 0.8, 0.8, 0.8, 1, 1, 1)
		local p = self.itemID and AH.prices[self.itemID]
		if p and p.unit then
			tip:AddDoubleLine("Cheapest", ns.Money(p.unit) .. " each", 0.8, 0.8, 0.8, 1, 1, 1)
			tip:AddDoubleLine("On sale", p.avail, 0.8, 0.8, 0.8, 1, 1, 1)
		end
		tip:AddLine("Click: search in the auction house. Shift-click: rescan.", 0.5, 0.8, 1, true)
	end)
	return b
end

local function build()
	local f = UI.Panel("CraftboundAuctionPanel", AuctionHouseFrame, 300, 400)
	f:SetPoint("TOPLEFT", AuctionHouseFrame, "TOPRIGHT", 2, 0)
	f:SetPoint("BOTTOMLEFT", AuctionHouseFrame, "BOTTOMRIGHT", 2, 0)
	f.title = UI.Text(f, "big", UI.GOLD)
	f.title:SetPoint("TOPLEFT", 10, -8)
	f.title:SetText("Craftbound shopping")
	f.logo = UI.TitleLogo(f, f.title, 22)
	f.guide = UI.Text(f, "small", { 0.8, 0.8, 0.8 })
	f.guide:SetPoint("TOPLEFT", 10, -28)
	f.guide:SetWidth(280)
	f.rows = UI.Pool(f, makeRow)
	f.more = UI.Text(f, "small", { 0.6, 0.6, 0.6 }, "RIGHT")
	f.more:SetPoint("BOTTOMRIGHT", -10, 96)
	f:EnableMouseWheel(true)
	f:SetScript("OnMouseWheel", function(self, delta)
		self.offset = math.max(0, math.min((self.offset or 0) - delta * 3, self.maxOffset or 0))
		ns.Refresh()
	end)

	f.buy = UI.Button(f, "Scan prices", 280, 28, function() AH.Press() end)
	f.buy:SetPoint("BOTTOMLEFT", 10, 64)
	f.cancel = UI.Button(f, "Cancel", 70, 20, cancelBuy)
	f.cancel:SetPoint("BOTTOMRIGHT", -10, 40)
	f.rescan = UI.Button(f, "Rescan", 70, 20, function()
		AH.prices = {}
		AH.ScanAll()
	end)
	f.rescan:SetPoint("RIGHT", f.cancel, "LEFT", -4, 0)
	f.total = UI.Text(f, "small", { 1, 1, 1 })
	f.total:SetPoint("BOTTOMLEFT", 10, 44)
	f.total:SetWidth(130)
	f.status = UI.Text(f, "small", { 0.9, 0.8, 0.5 })
	f.status:SetPoint("BOTTOMLEFT", 10, 8)
	f.status:SetWidth(280)
	UI.Tooltip(f.buy, function(tip)
		tip:AddLine("Buy next")
		tip:AddLine("Scans prices first, then buys the most-missing reagent. Commodities ask for a second click with the server's price.", nil, nil, nil, true)
		tip:AddLine("Bind a key: Key Bindings > AddOns > Craftbound.", 0.5, 0.8, 1, true)
	end)
	return f
end

local function render()
	if not panel or not panel:IsShown() then return end
	local f = panel
	local list, missing, guide = AH.List()
	if not guide then
		f.guide:SetText("Pick a guide first: /craft guide")
	else
		f.guide:SetText(("%s · %s: %d reagents still to get."):format(guide.profession, guide.name, missing))
	end
	f.rows:Reset()
	-- totals over the whole list; rows for the part that fits, scrolled with the mouse wheel
	local total, shortAny, shown = 0, false, {}
	for _, e in ipairs(list) do
		if e.missing > 0 then
			shown[#shown + 1] = e
			local id = ns.ItemID(e)
			local p = id and AH.prices[id]
			if p and p.unit and not VENDOR_ITEMS[id] then
				local cost, short = costNow(p, e.missing)
				total = total + cost
				if short > 0 then shortAny = true end
			end
		end
	end
	local fit = math.max(1, math.floor(((f:GetHeight() or 400) - 150) / 18))
	f.offset = math.max(0, math.min(f.offset or 0, #shown - fit))
	f.maxOffset = math.max(0, #shown - fit)
	local y = -46
	for i = f.offset + 1, math.min(#shown, f.offset + fit) do
		local e = shown[i]
		do
			local row = f.rows:Get()
			local id = ns.ItemID(e)
			row.entry, row.itemID = e, id
			row.icon:SetTexture(ns.ItemIcon(e))
			row.name:SetText(e.name)
			row.count:SetText("x" .. e.missing)
			local p = id and AH.prices[id]
			if id and VENDOR_ITEMS[id] then
				row.price:SetText(UI.Color("gray", "vendor"))
			elseif p and p.none then
				row.price:SetText(UI.Color({ 1, 0.4, 0.3 }, "none"))
			elseif p and p.unit then
				local cost, short = costNow(p, e.missing)
				row.price:SetText(ns.Money(cost) .. (short > 0 and UI.Color({ 1, 0.4, 0.3 }, "*") or ""))
			else
				row.price:SetText(UI.Color("gray", "?"))
			end
			row:ClearAllPoints()
			row:SetPoint("TOPLEFT", 8, y)
			y = y - 18
		end
	end
	f.rows:Finish()
	f.more:SetText(f.maxOffset > 0 and ("%d-%d of %d (mouse wheel)"):format(f.offset + 1, math.min(#shown, f.offset + fit), #shown) or "")
	f.total:SetText(total > 0 and ("Total: " .. ns.Money(total) .. (shortAny and UI.Color({ 1, 0.4, 0.3 }, " *not enough on sale") or "")) or "")
	local plan = AH.Plan()
	f.buy:SetText(plan.label)
	f.buy:SetEnabled(plan.enabled)
	f.cancel:SetShown(buying ~= nil and not buying.submitted)
	f.status:SetText(plan.warn and UI.Color({ 1, 0.4, 0.3 }, plan.warn) or AH.status)
end

ns.On("CB_REFRESH", render)

-- Show or hide the panel to match the setting while the auction house is open.
function AH.UpdatePanel()
	local want = isOpen and ns.db.settings.ahPanel and AuctionHouseFrame ~= nil
	if want and not panel then
		panel = build()
		ns.auctionPanel = panel
	end
	if panel then panel:SetShown(want and true or false) end
	render()
end

ns.On("AUCTION_HOUSE_SHOW", function()
	isOpen = true
	AH.status = ""
	AH.UpdatePanel()
end)

ns.On("AUCTION_HOUSE_CLOSED", function()
	isOpen = false
	queue, busy, waiting = {}, nil, nil
	-- a purchase already sent still reports back: keep it so it is counted
	if buying and not buying.submitted then buying = nil end
	AH.scanning = nil
end)

-- Merchants -----------------------------------------------------------------------------------

local merchantBtn

local function merchantPlan()
	local list = AH.List()
	local want = {}
	for _, e in ipairs(list) do
		local id = ns.ItemID(e)
		if id and e.missing > 0 then want[id] = e end
	end
	local buys, cost = {}, 0
	for i = 1, GetMerchantNumItems() do
		local id = GetMerchantItemID(i)
		local e = id and want[id]
		if e then
			local info = C_MerchantFrame.GetItemInfo(i)
			if info and info.isPurchasable ~= false then
				local qty = e.missing
				if info.numAvailable and info.numAvailable >= 0 then qty = math.min(qty, info.numAvailable) end
				if qty > 0 then
					local stack = info.stackCount or 1
					cost = cost + math.ceil(qty / stack) * (info.price or 0)
					buys[#buys + 1] = { index = i, qty = qty, name = e.name }
				end
			end
		end
	end
	return buys, cost
end

local function buyFromMerchant()
	local buys = merchantPlan()
	for _, b in ipairs(buys) do
		local left = b.qty
		local max = GetMerchantItemMaxStack(b.index) or left
		while left > 0 do
			local n = math.min(left, max)
			BuyMerchantItem(b.index, n)
			left = left - n
		end
		ns.Print(("Bought %d %s."):format(b.qty, b.name))
	end
end

ns.On("MERCHANT_SHOW", function()
	if not MerchantFrame then return end
	local buys, cost = merchantPlan()
	if not merchantBtn then
		merchantBtn = UI.Button(MerchantFrame, "", 200, 24, function(self)
			buyFromMerchant()
			self:Hide()
		end)
		-- below the window on the right: the Merchant and Buyback tabs sit below it on the left,
		-- and a second window (character, spellbook) opens to its right
		merchantBtn:SetPoint("TOPRIGHT", MerchantFrame, "BOTTOMRIGHT", -4, -2)
		UI.Tooltip(merchantBtn, function(tip)
			tip:AddLine("Craftbound")
			for _, b in ipairs((merchantPlan())) do tip:AddLine(("%s x%d"):format(b.name, b.qty), 1, 1, 1) end
		end)
	end
	if buys[1] then
		merchantBtn:SetText(("Buy route reagents (%s)"):format(ns.Money(cost)))
		merchantBtn:Show()
	else
		merchantBtn:Hide()
	end
end)

ns.On("MERCHANT_CLOSED", function() if merchantBtn then merchantBtn:Hide() end end)
