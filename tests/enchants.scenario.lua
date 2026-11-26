--@moods: target wrong plain overwrite gone later twin laterplain blocked cancel
-- Enchant targets: items in the bags (the sidebar) take the route's enchants, and their "replace
-- the enchant?" and "bind it?" questions are answered in the same press. Without one the equipped
-- item gets it, and the game asks, unless "Overwrite my enchants" is on (with a warning first).
-- When the game asks a moment after the press, Craftbound answers right then, but only for questions
-- that are yours to skip (a sidebar item, or Overwrite on). If the client blocks that, the next
-- press answers, and Craftbound stops trying.
local T = dofile(wb.dir .. "/tests/_helper.lua")
local m = wb.mood
local s = wb.state
s.player.level = 30
s.bags[10940] = 30 -- Strange Dust
s.bags[10938] = 30 -- Lesser Magic Essence
s.bags[6218] = 1   -- Runed Copper Rod
s.items[2000] = { name = "Worn Robe", equipLoc = "INVTYPE_ROBE", icon = 132000 }
s.items[3000] = { name = "My Best Chest", equipLoc = "INVTYPE_CHEST", icon = 133000 }
s.slots[5] = 3000 -- worn
s.items[2001] = { name = "Old Bracers", equipLoc = "INVTYPE_WRIST" }
s.bags[2000] = 1
local target = m == "target" or m == "later" or m == "twin" or m == "blocked" or m == "cancel"
local later = m == "later" or m == "laterplain" or m == "blocked" or m == "cancel"
s.bags[2001] = 1

wb.login({ saved = T.professionGlobals({ [T.ENCHANTING] = { name = "Enchanting", rank = 79, max = 150 } }) })
local ts = T.tradeSkill(T.ENCHANTING, "Enchanting", 79, 150, T.enchantingRecipes())
local cursor
local popups, replaced, bound, hidden = {}, 0, 0, {}
local blockOnce = m == "blocked"
T.inject({
	C_TradeSkillUI = ts,
	Enum = { TradeskillRecipeType = { Enchant = 3 } },
	ItemLocation = {
		CreateFromEquipmentSlot = function(_, slot) return { slot = slot, IsValid = function() return true end } end,
		CreateFromBagAndSlot = function(_, bag, slot) return { bag = bag, bagSlot = slot, IsValid = function() return true end } end,
	},
	C_Item = setmetatable({
		ReplaceEnchant = function()
			if blockOnce then -- the client refuses an addon outside a key press
				blockOnce = false
				wb.fire("ADDON_ACTION_BLOCKED", "Craftbound", "C_Item.ReplaceEnchant()")
				return
			end
			replaced = replaced + 1
		end,
		BindEnchant = function() bound = bound + 1 end,
	}, { __index = wb.G.C_Item }),
	GetCursorInfo = function() if cursor then return "item", cursor end end,
	ClearCursor = function() cursor = nil end,
	StaticPopup_Show = function(which) popups[#popups + 1] = which end,
	StaticPopup_Hide = function(which) hidden[#hidden + 1] = which end,
	GetInventoryItemTexture = function(_, slot) return s.slots[slot] and s.items[s.slots[slot]].icon or nil end,
	-- the game's own questions stay up until answered (the bind one under its newer name)
	StaticPopup_Visible = function(which) return which == "REPLACE_ENCHANT" or which == "ENCHANT_BIND" end,
})
-- the client asks while the cast starts (inside the press), or a moment later ("later")
local craft = ts.CraftEnchant
ts.CraftEnchant = function(...)
	craft(...)
	if not later then wb.fire("REPLACE_ENCHANT", "Old", "New"); wb.fire("BIND_ENCHANT") end
end
if m == "twin" then
	-- two Worn Robes: slot 1 is enchanted already, slot 2 is the one dragged (locked on the cursor)
	local bag = { [1] = { id = 2000, guid = "Item-1" }, [2] = { id = 2000, guid = "Item-2", locked = true } }
	T.inject({
		C_Container = setmetatable({
			GetContainerNumSlots = function(b) return b == 0 and 2 or 0 end,
			GetContainerItemID = function(b, slot) return b == 0 and bag[slot] and bag[slot].id or nil end,
			GetContainerItemInfo = function(b, slot)
				local i = b == 0 and bag[slot]
				return i and { itemID = i.id, isLocked = i.locked == true } or nil
			end,
		}, { __index = wb.G.C_Container }),
	})
	wb.G.C_Item.GetItemGUID = function(loc) return loc.bag == 0 and bag[loc.bagSlot] and bag[loc.bagSlot].guid or nil end
	wb.ns.twinBag = bag
end
local pf = wb.G.CreateFrame("Frame", "ProfessionsFrame", wb.G.UIParent)
pf.CraftingPage = { SelectRecipe = function() end }
pf:Show()
wb.fire("TRADE_SKILL_SHOW")
wb.advance(0.5)

local side = wb.frame("CraftboundEnchantTargets")
wb.check(side and wb.shown("CraftboundEnchantTargets"), "the enchant targets sidebar is shown for Enchanting")
local chest = side and side.slots and side.slots.Chest
wb.check(chest ~= nil, "a Chest slot (the route enchants chests)")
local function drop(id) cursor = id; chest:GetScript("OnReceiveDrag")(chest) end
if m == "plain" then
	wb.expect("no item picked: the slot shows what you wear (it gets the enchant)", chest.icon:GetTexture(), 133000)
end

if m == "wrong" then
	drop(2001)
	wb.expect("a bracer doesn't go in the Chest slot", wb.saved("CraftboundCharDB").enchantTargets.Chest, nil)
	wb.check(wb.printed("Old Bracers can't take a chest enchant"), "says why")
	return
end

if target or m == "gone" then
	cursor = 2000
	chest:GetScript("OnReceiveDrag")(chest)
	local saved = wb.saved("CraftboundCharDB").enchantTargets.Chest
	wb.expect("the robe is the chest target", saved and saved.id, 2000)
	wb.expect("taken off the cursor", cursor, nil)
	wb.advance(0.1)
	wb.expect("the slot shows the picked item", chest.icon:GetTexture(), 132000)
	local tip = wb.ns.CraftTarget and wb.ns.CraftTarget()
	wb.check(tip and tip:find("Worn Robe", 1, true), "Craft says where it goes: " .. tostring(tip))
	if m == "gone" then
		s.bags[2000] = nil -- sold since: the equipped chest gets it
		wb.advance(0.1)
		wb.expect("a picked item no longer in the bags still shows (greyed)", chest.icon:GetTexture(), 132000)
	end
end

if m == "overwrite" then
	local btn = wb.frame("CraftboundProfessionPanel").overwrite
	btn:GetScript("OnClick")(btn)
	wb.expect("turning it on asks first", popups[#popups], "CRAFTBOUND_OVERWRITE")
	wb.expect("not on before the answer", wb.saved("CraftboundDB").settings.overwriteEnchants, false)
	wb.ns.OverwritePopup.OnAccept()
	wb.expect("on after yes", wb.saved("CraftboundDB").settings.overwriteEnchants, true)
end

wb.ns.CraftNext()
local cast = ts.calls.enchant[#ts.calls.enchant]
wb.check(cast ~= nil, "one enchant cast")
if target then
	wb.expect("on the robe in the bags", cast.loc.bag, 0)
	if m == "twin" then wb.expect("the very robe that was dragged, not its twin", cast.loc.bagSlot, 2) end
	wb.expect("not on the equipped chest", cast.loc.slot, nil)
else
	wb.expect("on the equipped chest (" .. m .. ")", cast.loc.slot, 5)
end

if m == "twin" then
	wb.ns.twinBag[2] = nil -- sold: the other robe is not the target
	wb.G.C_Item.GetItemGUID = function(loc) return loc.bag == 0 and wb.ns.twinBag[loc.bagSlot] and wb.ns.twinBag[loc.bagSlot].guid or nil end
	wb.ns.CraftNext() -- answers the replace first
	wb.ns.CraftNext()
	local again = ts.calls.enchant[#ts.calls.enchant]
	wb.expect("its twin is never taken instead: the equipped chest", again.loc.slot, 5)
	return
end
if m == "later" then
	-- in game the question comes after the cast: seconds later, after UNIT_SPELLCAST_SUCCEEDED
	wb.advance(6)
	wb.fire("UNIT_SPELLCAST_SUCCEEDED", "player")
	wb.fire("REPLACE_ENCHANT", "Old", "New")
	wb.expect("asked after the cast: answered right then", replaced, 1)
	wb.fire("BIND_ENCHANT")
	wb.expect("and the bind question too", bound, 1)
	wb.advance(0.1)
	wb.check(hidden[1] == "REPLACE_ENCHANT", "the game's question is taken away")
	wb.check(wb.ns.CraftPlan().label:find("^Enchant"), "the button moves on: " .. wb.ns.CraftPlan().label)
	-- another enchant started from Blizzard's window right after: its question is the player's
	wb.fire("REPLACE_ENCHANT", "Mine", "Other")
	wb.expect("only our enchant's question is answered, once", replaced, 1)
	return
end
if m == "cancel" then
	wb.fire("UNIT_SPELLCAST_FAILED", "player")
	wb.fire("REPLACE_ENCHANT", "Mine", "Other")
	wb.expect("our cast failed: a later question is the player's", replaced, 0)
	return
end
if m == "laterplain" then
	wb.fire("REPLACE_ENCHANT", "Old", "New")
	wb.expect("your own gear, Overwrite off: never answered for you", replaced, 0)
	wb.expect("the next press answers it", wb.ns.CraftPlan().label, "Replace enchant")
	wb.ns.CraftNext()
	wb.expect("answered by that press", replaced, 1)
	return
end
if m == "blocked" then
	wb.fire("REPLACE_ENCHANT", "Old", "New")
	wb.fire("BIND_ENCHANT") -- both asked before the next frame: the bind must not undo the block
	wb.advance(0.1)
	wb.expect("blocked: not answered", replaced, 0)
	wb.check(hidden[1] ~= "REPLACE_ENCHANT", "the question stays up")
	wb.expect("the next press answers it", wb.ns.CraftPlan().label, "Replace enchant")
	wb.ns.CraftNext()
	wb.expect("answered by that press", replaced, 1)
	wb.expect("remembered: no more tries from the event", wb.saved("CraftboundDB").settings.answerBlocked, true)
	return
end
if m == "target" or m == "overwrite" then
	wb.expect("the replace question answered in the same press", replaced, 1)
	wb.check(wb.ns.CraftPlan().label ~= "Replace enchant", "and the button moves on")
else
	wb.expect("your own gear: the game asks", replaced, 0)
	wb.expect("the next press answers it", wb.ns.CraftPlan().label, "Replace enchant")
end
wb.expect("binding answered only for a bag target", bound, m == "target" and 1 or 0)

if m == "target" then
	chest:GetScript("OnClick")(chest, "RightButton")
	wb.expect("right-click clears the slot", wb.saved("CraftboundCharDB").enchantTargets.Chest, nil)
end
