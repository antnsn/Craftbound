-- Items: what the character owns, and item IDs for materials the guide knows only by name.
--
-- Counts come from C_Item.GetItemCount(id, includeBank): the client keeps the bank's contents,
-- so the bank counts even when it is closed (after it was opened once this session or before).
local _, ns = ...

-- The item ID of a material ({ id, name }), learning IDs by name when the client knows the item.
function ns.ItemID(mat)
	if mat.id then return mat.id end
	local name = mat.name
	if not name then return nil end
	local id = ns.KnownIDs[name] or ns.db.items[name]
	if id then return id end
	if C_Item and C_Item.GetItemIDForItemInfo then
		local ok, found = pcall(C_Item.GetItemIDForItemInfo, name)
		if ok and type(found) == "number" then
			ns.db.items[name] = found
			return found
		end
	end
end

-- Names the guides give IDs for (materials and tools), built once at load.
ns.KnownIDs = {}
for _, g in ipairs(ns.Guides) do
	for _, s in ipairs(g.steps) do
		for _, m in ipairs(s.mats or {}) do
			if m.id then ns.KnownIDs[m.name] = m.id end
		end
		if s.kind == "tool" and s.item then ns.KnownIDs[s.recipe] = s.item end
	end
	for name, part in pairs(g.parts or {}) do
		if part.id then ns.KnownIDs[name] = part.id end
		for _, m in ipairs(part.mats or {}) do
			if m.id then ns.KnownIDs[m.name] = m.id end
		end
	end
end

-- Teach an item ID found some other way (auction house browse, recipe reagents).
function ns.LearnItem(name, id)
	if name and id and not ns.db.items[name] then ns.db.items[name] = id end
end

function ns.Have(mat)
	local id = ns.ItemID(mat)
	if not id then return 0 end
	local n = C_Item.GetItemCount(id, true)
	return (type(n) == "number" and n or 0) + (ns.char.mail[id] or 0)
end

function ns.BagCount(mat)
	local id = ns.ItemID(mat)
	if not id then return 0 end
	local n = C_Item.GetItemCount(id)
	return type(n) == "number" and n or 0
end

function ns.ItemIcon(mat)
	local id = ns.ItemID(mat)
	if id and C_Item.GetItemIconByID then return C_Item.GetItemIconByID(id) end
	return 134400 -- question mark
end

local mailOpen, bagSeen = false, {}

-- Auction purchases go to the mailbox: count them until they are collected.
function ns.AddMail(id, qty)
	if id and qty and qty > 0 then ns.char.mail[id] = (ns.char.mail[id] or 0) + qty end
	ns.Refresh()
end

-- The open mailbox is the truth: recount every attachment in it.
ns.On("MAIL_INBOX_UPDATE", function()
	local found = {}
	local max = ATTACHMENTS_MAX_RECEIVE or 16
	local loaded, total = GetInboxNumItems()
	loaded = loaded or 0
	for i = 1, loaded do
		for a = 1, max do
			local _, id, _, count = GetInboxItem(i, a)
			if type(id) == "number" then found[id] = (found[id] or 0) + (count or 1) end
		end
	end
	ns.mailPartial = total and total > loaded or false
	if ns.mailPartial then
		-- only part of the inbox is loaded: what we see is at least there, keep the rest
		for id, n in pairs(found) do
			if mailOpen and bagSeen[id] == nil then bagSeen[id] = ns.BagCount({ id = id }) end
			if n > (ns.char.mail[id] or 0) then ns.char.mail[id] = n end
		end
	else
		ns.char.mail = found
	end
	ns.Refresh()
end)

-- While the mailbox is open, what lands in the bags came out of it.
ns.On("MAIL_SHOW", function()
	mailOpen, bagSeen = true, {}
	for id in pairs(ns.char.mail) do bagSeen[id] = ns.BagCount({ id = id }) end
end)
ns.On("MAIL_CLOSED", function() mailOpen = false end)

-- Bags changed: counts and the shopping list follow.
ns.On("BAG_UPDATE_DELAYED", function()
	-- a fully loaded inbox is recounted on MAIL_INBOX_UPDATE; only a partial one needs this
	if mailOpen and ns.mailPartial ~= false then
		for id, n in pairs(ns.char.mail) do
			local now = ns.BagCount({ id = id })
			local gained = now - (bagSeen[id] or now)
			if gained > 0 then ns.char.mail[id] = (n - gained > 0) and (n - gained) or nil end
			bagSeen[id] = now
		end
	end
	ns.Refresh()
end)
ns.On("BANKFRAME_OPENED", function() ns.Refresh() end)
