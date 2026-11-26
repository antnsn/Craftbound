-- Enchant targets: where the route's enchants go. A sidebar beside the profession panel holds one
-- item per kind (Chest, Bracer...) dragged from the bags, that very item (its GUID): those enchants go on it instead of your
-- gear, and the game's "replace the enchant?" and "bind it to you?" questions are answered in the
-- same press. Without one the equipped item gets it; the game asks, unless "Overwrite my enchants"
-- is on. Answers only ever come from the press (Profession.lua), never from an event.
local _, ns = ...

local UI = ns.UI

-- the recipe's "Enchant <kind> - ...": the equipped slot, and what an item in the bags must be
local KINDS = {
	Chest = { slot = 5, locs = { INVTYPE_CHEST = true, INVTYPE_ROBE = true } },
	Bracer = { slot = 9, locs = { INVTYPE_WRIST = true } },
	Boots = { slot = 8, locs = { INVTYPE_FEET = true } },
	Gloves = { slot = 10, locs = { INVTYPE_HAND = true } },
	Cloak = { slot = 15, locs = { INVTYPE_CLOAK = true } },
	Shield = { slot = 17, locs = { INVTYPE_SHIELD = true } },
	Weapon = { slot = 16, locs = { INVTYPE_WEAPON = true, INVTYPE_WEAPONMAINHAND = true,
		INVTYPE_WEAPONOFFHAND = true, INVTYPE_2HWEAPON = true } },
	["2H Weapon"] = { slot = 16, locs = { INVTYPE_2HWEAPON = true } },
}
local ORDER = { "Chest", "Bracer", "Boots", "Gloves", "Cloak", "Shield", "Weapon", "2H Weapon" }

function ns.EnchantKind(recipe)
	local part = type(recipe) == "string" and recipe:match("^Enchant (.-) %- ")
	return part and KINDS[part] and part or nil
end

local function itemName(id)
	local ok, n = pcall(C_Item.GetItemNameByID, id)
	return ok and type(n) == "string" and n or ("item " .. id)
end

local function guidAt(bag, slot)
	if not (C_Item.GetItemGUID and ItemLocation and ItemLocation.CreateFromBagAndSlot) then return nil end
	local ok, guid = pcall(C_Item.GetItemGUID, ItemLocation:CreateFromBagAndSlot(bag, slot))
	return ok and type(guid) == "string" and guid or nil
end

local function eachSlot(fn)
	for bag = 0, NUM_BAG_SLOTS or 4 do
		for slot = 1, C_Container.GetContainerNumSlots(bag) or 0 do
			local r1, r2 = fn(bag, slot, C_Container.GetContainerItemID(bag, slot))
			if r1 then return r1, r2 end
		end
	end
end

-- the target item in the bags: that very item (by GUID), never another copy of it
local function findInBags(t)
	if type(t) ~= "table" then return nil end
	return eachSlot(function(bag, slot, id)
		if id == t.id and (not t.guid or guidAt(bag, slot) == t.guid) then return bag, slot end
	end)
end

-- the item on the cursor, in the bags: the copy the game locked while it is held, or the only copy
local function dragged(id)
	local copies, only = 0, nil
	local bag, slot = eachSlot(function(b, s, sid)
		if sid ~= id then return end
		copies, only = copies + 1, { b, s }
		local info = C_Container.GetContainerItemInfo(b, s)
		if type(info) == "table" and info.isLocked then return b, s end
	end)
	if bag then return bag, slot end
	if copies == 1 then return only[1], only[2] end
end

-- Where this recipe's enchant goes: an ItemLocation, whether its questions are answered for you,
-- and whether it is the sidebar's item in the bags.
function ns.EnchantTarget(recipe)
	local kind = ns.EnchantKind(recipe)
	if not kind or not ItemLocation then return nil end
	local bag, slot = findInBags(ns.char.enchantTargets[kind])
	if bag and ItemLocation.CreateFromBagAndSlot then
		return ItemLocation:CreateFromBagAndSlot(bag, slot), true, true
	end
	return ItemLocation:CreateFromEquipmentSlot(KINDS[kind].slot), ns.db.settings.overwriteEnchants == true, false
end

-- Where the current step's enchant goes, as a line for the Craft button's tooltip (nil: no enchant)
function ns.CraftTarget()
	local st = ns.Status()
	local kind = st and st.step and ns.EnchantKind(st.step.recipe)
	if not kind then return nil end
	local tgt = ns.char.enchantTargets[kind]
	if type(tgt) == "table" and findInBags(tgt) then
		return ("Goes on: %s (in your bags)"):format(itemName(tgt.id))
	end
	local worn = GetInventoryItemID("player", KINDS[kind].slot)
	if worn then
		return ("Goes on: your %s (%s)"):format(itemName(worn),
			ns.db.settings.overwriteEnchants and "its enchant is replaced" or "the game asks before replacing its enchant")
	end
	return ("Goes on: nothing worn in the %s slot, the game asks you to pick an item"):format(kind:lower())
end

-- Overwrite my enchants: asks before it turns on
local POPUP = "CRAFTBOUND_OVERWRITE"
ns.OverwritePopup = {
	text = "Overwrite your enchants?\n\nFrom now on every enchant of the route goes on your equipped gear "
		.. "(unless the sidebar has an item for it) and replaces whatever enchant is on it today, without asking. "
		.. "The old enchants are gone for good.",
	button1 = "Overwrite",
	button2 = "Cancel",
	OnAccept = function()
		ns.db.settings.overwriteEnchants = true
		ns.Print("Overwrite my enchants is on: your equipped enchants will be replaced without asking.")
		ns.Refresh()
	end,
	timeout = 0,
	whileDead = true,
	hideOnEscape = true,
	showAlert = true,
	preferredIndex = 3,
}
local dialogs = rawget(_G, "StaticPopupDialogs")
if dialogs then dialogs[POPUP] = ns.OverwritePopup end

function ns.ToggleOverwrite()
	if ns.db.settings.overwriteEnchants then
		ns.db.settings.overwriteEnchants = false
		ns.Refresh()
	elseif StaticPopup_Show then
		StaticPopup_Show(POPUP)
	end
end

-- The sidebar ------------------------------------------------------------------------------

local function setTarget(kind, id)
	ns.char.enchantTargets[kind] = id
	ns.Refresh()
end

local function onDrop(self)
	local what, id = GetCursorInfo()
	if what ~= "item" or type(id) ~= "number" then return false end
	local loc = select(4, C_Item.GetItemInfoInstant(id))
	local bag, slot = dragged(id)
	if not KINDS[self.kind].locs[loc] then
		ns.Print(("%s can't take a %s enchant."):format(itemName(id), self.kind:lower()))
	elseif not bag then
		ns.Print(("Drag %s from your bags."):format(itemName(id)))
	else
		setTarget(self.kind, { id = id, guid = guidAt(bag, slot) })
		ns.Print(("%s takes the %s enchants now."):format(itemName(id), self.kind:lower()))
	end
	ClearCursor()
	return true
end

local function makeSlot(parent, kind)
	local b = CreateFrame("Button", nil, parent)
	b.kind = kind
	b:SetSize(36, 36)
	b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	b.icon = b:CreateTexture(nil, "ARTWORK")
	b.icon:SetAllPoints()
	b.label = UI.Text(b, "small", { 0.8, 0.8, 0.8 }, "CENTER")
	b.label:SetPoint("TOP", b, "BOTTOM", 0, -1)
	b.label:SetWidth(60)
	b.label:SetWordWrap(false)
	b.label:SetText(kind)
	b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
	b:SetScript("OnReceiveDrag", onDrop)
	b:SetScript("OnClick", function(self, button)
		if button == "RightButton" then setTarget(self.kind, nil) return end
		onDrop(self)
	end)
	UI.Tooltip(b, function(tip, self)
		local tgt = ns.char.enchantTargets[self.kind]
		local id = type(tgt) == "table" and tgt.id or nil
		tip:AddLine(self.kind .. " enchants go on", 1, 1, 1)
		if id and findInBags(tgt) then
			tip:AddLine(itemName(id), 0.3, 1, 0.3)
			tip:AddLine("The game's questions about it are answered for you.", nil, nil, nil, true)
		elseif id then
			tip:AddLine(itemName(id) .. " is not in your bags: your equipped item gets them.", 1, 0.5, 0.4, true)
		else
			tip:AddLine("Your equipped item.", nil, nil, nil, true)
		end
		tip:AddLine("Drag an item from your bags here to enchant it instead of your gear. Right-click: clear.", 0.5, 0.8, 1, true)
	end)
	return b
end

-- Show the sidebar beside the panel for an Enchanting guide: one slot per kind the route enchants.
function ns.RenderEnchantTargets(panel, guide, step)
	local side = panel.enchantSide
	if not guide or guide.profession ~= "Enchanting" then
		if side then side:Hide() end
		return
	end
	if not side then
		side = UI.Panel("CraftboundEnchantTargets", panel, 70, 100)
		side:SetPoint("TOPLEFT", panel, "TOPRIGHT", 2, 0)
		side.title = UI.Text(side, "small", UI.GOLD, "CENTER")
		side.title:SetPoint("TOP", 0, -8)
		side.title:SetWidth(64)
		side.title:SetText("Enchant on")
		side.slots = {}
		panel.enchantSide = side
	end
	local used = {}
	for _, s in ipairs(guide.steps or {}) do
		local kind = s.kind == "craft" and ns.EnchantKind(s.recipe)
		if kind then used[kind] = true end
	end
	local y, current = -26, step and ns.EnchantKind(step.recipe)
	for _, kind in ipairs(ORDER) do
		local b = side.slots[kind]
		if used[kind] then
			b = b or makeSlot(side, kind)
			side.slots[kind] = b
			b:ClearAllPoints()
			b:SetPoint("TOP", 0, y)
			local tgt = ns.char.enchantTargets[kind]
			local id = type(tgt) == "table" and tgt.id or nil
			local here = id and findInBags(tgt)
			-- the picked item (greyed when it left the bags), else what you wear: it gets the enchant
			local icon = id and C_Item.GetItemIconByID(id)
				or GetInventoryItemTexture("player", KINDS[kind].slot)
			b.icon:SetTexture(icon or "Interface\\PaperDoll\\UI-Backpack-EmptySlot")
			b.icon:SetDesaturated(id ~= nil and not here)
			b.icon:SetAlpha(id and 1 or 0.75)
			b.label:SetTextColor(unpack(kind == current and UI.GOLD or { 0.8, 0.8, 0.8 }))
			b:Show()
			y = y - 54
		elseif b then
			b:Hide()
		end
	end
	side:SetHeight(-y + 4)
	side:Show()
end
