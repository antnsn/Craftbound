-- Shared setup for the Craftbound scenarios: a fake Forever profession window and auction house.
-- The stand-in client doesn't model C_TradeSkillUI or C_AuctionHouse, so these fakes record
-- what the addon calls and answer like the client would.
local T = {}

T.ENCHANTING = 333
T.ALCHEMY = 171

-- Character professions: { [skillLine] = { name, rank, max } }
function T.professionGlobals(profs)
	local order = {}
	for line, p in pairs(profs) do order[#order + 1] = { line = line, p = p } end
	table.sort(order, function(a, b) return a.line < b.line end)
	return {
		GetProfessions = function()
			return order[1] and 1 or nil, order[2] and 2 or nil
		end,
		GetProfessionInfo = function(i)
			local o = order[i]
			if not o then return nil end
			return o.p.name, 136244, o.p.rank, o.p.max, 0, 0, o.line
		end,
	}
end

-- A fake C_TradeSkillUI for one open profession.
-- recipes: list of { id, name, learned, difficulty, craftable, mats = { {itemID, qty} }, enchant }
function T.tradeSkill(line, name, skill, max, recipes)
	local calls = { craft = {}, enchant = {}, opened = {} }
	local byID = {}
	for _, r in ipairs(recipes) do byID[r.id] = r end
	local api = {
		calls = calls,
		IsTradeSkillReady = function() return true end,
		IsTradeSkillLinked = function() return false end,
		IsTradeSkillGuild = function() return false end,
		IsNPCCrafting = function() return false end,
		GetBaseProfessionInfo = function()
			return { professionID = line, professionName = name, skillLevel = skill, maxSkillLevel = max }
		end,
		GetAllRecipeIDs = function()
			local ids = {}
			for _, r in ipairs(recipes) do ids[#ids + 1] = r.id end
			return ids
		end,
		GetFilteredRecipeIDs = function() return {} end,
		GetRecipeInfo = function(id)
			local r = byID[id]
			if not r then return nil end
			return { recipeID = r.id, name = r.name, learned = r.learned ~= false, relativeDifficulty = r.difficulty or 0 }
		end,
		GetRecipeSchematic = function(id)
			local r = byID[id]
			local slots = {}
			for _, m in ipairs(r.mats or {}) do
				slots[#slots + 1] = { quantityRequired = m[2], required = true, reagents = { { itemID = m[1] } } }
			end
			return { reagentSlotSchematics = slots, recipeType = r.enchant and 3 or 1 }
		end,
		GetCraftableCount = function(id) return byID[id] and byID[id].craftable or 0 end,
		CraftRecipe = function(id, n) calls.craft[#calls.craft + 1] = { id = id, n = n } end,
		CraftEnchant = function(id, n, _, loc) calls.enchant[#calls.enchant + 1] = { id = id, n = n, loc = loc } end,
		OpenRecipe = function(id) calls.opened[#calls.opened + 1] = id end,
		set = function(newSkill) skill = newSkill end,
	}
	return api
end

-- A fake C_AuctionHouse. market: { [itemID] = { {unitPrice, quantity}, ... } }
function T.auctionHouse(market)
	local calls = { search = {}, start = {}, confirm = {}, cancel = 0, bid = {} }
	local api = {
		calls = calls,
		IsThrottledMessageSystemReady = function() return true end,
		MakeItemKey = function(id) return { itemID = id } end,
		SendSearchQuery = function(key) calls.search[#calls.search + 1] = key.itemID end,
		SendBrowseQuery = function(q) calls.browse = q.searchString end,
		GetBrowseResults = function() return {} end,
		HasFullCommoditySearchResults = function() return true end,
		HasFullItemSearchResults = function() return true end,
		GetNumCommoditySearchResults = function(id) return market[id] and #market[id] or 0 end,
		GetCommoditySearchResultInfo = function(id, i)
			local r = market[id][i]
			return { unitPrice = r[1], quantity = r[2], numOwnerItems = 0 }
		end,
		GetNumItemSearchResults = function() return 0 end,
		StartCommoditiesPurchase = function(id, qty) calls.start[#calls.start + 1] = { id = id, qty = qty } end,
		ConfirmCommoditiesPurchase = function(id, qty) calls.confirm[#calls.confirm + 1] = { id = id, qty = qty } end,
		CancelCommoditiesPurchase = function() calls.cancel = calls.cancel + 1 end,
		PlaceBid = function(id, amount) calls.bid[#calls.bid + 1] = { id = id, amount = amount } end,
	}
	return api
end

-- Put fakes into the addon's environment (after wb.login/wb.reload).
function T.inject(globals)
	for k, v in pairs(globals) do rawset(wb.G, k, v) end
end

-- The real Enchanting recipes of the first steps, with IDs.
function T.enchantingRecipes(opts)
	opts = opts or {}
	return {
		{ id = 1001, name = "Runed Copper Rod", mats = { { 6217, 1 }, { 99001, 1 } }, craftable = 1 },
		{ id = 1002, name = "Dust to Motes", mats = { { 10940, 1 } }, craftable = 5 },
		{ id = 1003, name = "Enchant Chest - Inferior Stamina", mats = { { 10940, 1 } },
			craftable = opts.craftable or 40, enchant = true, difficulty = 0 },
		{ id = 1004, name = "Enchant Chest - Minor Absorption", mats = { { 10938, 1 } }, craftable = 0, learned = false },
	}
end

return T
