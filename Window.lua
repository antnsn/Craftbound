-- The Craftbound window (/craft, minimap left-click): every guide, built-in and custom, with
-- where to stop and what that costs, the custom guide editor, and export/import as text.
local _, ns = ...

local UI = ns.UI
local P = ns.Planner

local W = {}
ns.Window = W

local WIDTH, HEIGHT = 780, 500
local LIST_ROW, ROUTE_ROW, EDIT_ROW = 34, 16, 24

local win, share
local selected            -- key of the guide shown on the right
local mode = "details"    -- "details" or "edit"
local draft, draftKey     -- the guide being edited (a copy) and the custom key it replaces (nil: new)
local confirmDelete       -- key waiting for the second click on Delete
local search = ""
local refill              -- the editor's text boxes need filling from the draft (not while typing)

local function message(text, bad)
	if not win then return end
	win.msg:SetText(bad and UI.Color({ 1, 0.4, 0.3 }, text) or text)
end

local function sortedGuides()
	local t = {}
	for _, g in ipairs(ns.Guides) do t[#t + 1] = g end
	table.sort(t, function(a, b)
		if a.profession ~= b.profession then return a.profession < b.profession end
		if (a.custom or false) ~= (b.custom or false) then return not a.custom end
		return a.name < b.name
	end)
	return t
end

-- A mouse-wheel list: offset kept on the frame, clamped by the renderer.
local function wheel(f, key)
	f:EnableMouseWheel(true)
	f:SetScript("OnMouseWheel", function(_, delta)
		f[key] = math.max(0, (f[key] or 0) - delta * 2)
		refill = true
		W.Render()
	end)
end

-- Guide list ---------------------------------------------------------------------------------

local function makeGuideRow(parent)
	local b = CreateFrame("Button", nil, parent)
	b:SetSize(236, LIST_ROW - 2)
	b.bg = b:CreateTexture(nil, "BACKGROUND")
	b.bg:SetAllPoints()
	b.bg:SetColorTexture(0.88, 0.63, 0.25, 0.18)
	b:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
	b.name = UI.Text(b, nil, { 1, 1, 1 })
	b.name:SetPoint("TOPLEFT", 6, -3)
	b.name:SetWidth(226)
	b.name:SetWordWrap(false)
	b.sub = UI.Text(b, "small", { 0.65, 0.65, 0.65 })
	b.sub:SetPoint("TOPLEFT", 6, -18)
	b.sub:SetWidth(226)
	b.sub:SetWordWrap(false)
	b:SetScript("OnClick", function(self)
		if mode == "edit" then
			return message("Save or cancel the guide you are editing first.", true)
		end
		selected, confirmDelete = self.key, nil
		message("")
		W.Render()
	end)
	return b
end

local function renderList()
	local f = win.left
	local guides = sortedGuides()
	local fit = math.floor((f:GetHeight() - 4) / LIST_ROW)
	f.offset = math.max(0, math.min(f.offset or 0, #guides - fit))
	f.rows:Reset()
	for i = f.offset + 1, math.min(#guides, f.offset + fit) do
		local g = guides[i]
		local r = f.rows:Get()
		r.key = g.key
		r:ClearAllPoints()
		r:SetPoint("TOPLEFT", 0, -(i - f.offset - 1) * LIST_ROW)
		r.bg:SetShown(g.key == selected)
		r.name:SetText(("%s · %s"):format(g.profession, g.name)
			.. (ns.char.active == g.key and UI.Color("green", "  (active)") or ""))
		local s = ns.char.skills[g.profession]
		local bits = { ("%d-%d"):format(g.from, g.to) }
		bits[#bits + 1] = s and ("skill %d"):format(s.rank) or "not learned"
		if g.custom then bits[#bits + 1] = UI.Color({ 0.6, 0.8, 1 }, "custom") end
		r.sub:SetText(table.concat(bits, " · "))
	end
	f.rows:Finish()
end

-- Details ------------------------------------------------------------------------------------

local function stepLabel(s)
	if s.kind == "train" then return (s.how and "Learn " or "Train ") .. s.rank .. (" (before %d)"):format(s.before) end
	if s.kind == "disenchant" then return ("%d-%d Disenchant"):format(s.from, s.to) end
	if s.kind == "tool" then return (s.buy and "Buy: " or "Tool: ") .. s.recipe end
	return ("%d-%d %s"):format(s.from, s.to, s.recipe)
end

local function costText(c)
	if c.missing == 0 and c.recipes == 0 then return UI.Color("green", "nothing to buy") end
	local t = "~" .. ns.Money(c.copper)
	if c.unpriced > 0 then t = t .. "\n" .. UI.Color({ 1, 0.6, 0.3 }, ("+%d unpriced"):format(c.unpriced)) end
	return t
end

local function renderDetails(g)
	local d = win.details
	local st, ctx = ns.Status(g)
	d.name:SetText(("%s · %s"):format(g.profession, g.name))
	local sub = { ("%d-%d"):format(g.from, g.to) }
	if g.avgCrafts then sub[#sub + 1] = ("~%d crafts"):format(g.avgCrafts) end
	sub[#sub + 1] = g.custom and ("custom" .. (g.author and (", by " .. g.author) or "")) or "built-in"
	d.sub:SetText(table.concat(sub, " · "))
	local s = ns.char.skills[g.profession]
	d.skill:SetText(s and ("Your skill: %d / %d%s"):format(s.rank, s.max or 0,
		st.finished and UI.Color("green", "  · done to your stop") or "")
		or ("You don't have %s on this character: costs are from the start."):format(g.profession))

	-- stop targets, each with its cost from here
	local targets = ns.Targets(g)
	local current = st.stop
	local last
	for k, b in ipairs(d.targets) do
		local t = targets[k]
		b:SetShown(t ~= nil)
		b.cost:SetShown(t ~= nil)
		if t then
			b.target = t
			b:SetText((t == current and "> %d <" or "%d"):format(t))
			if t == current then b:LockHighlight() else b:UnlockHighlight() end
			local c = ns.Prices.CostTo(g, t)
			b.cost:SetText(costText(c))
			if t == current then last = c end
		end
	end
	d.prices:SetText(last and ns.Prices.Describe(last) or "")

	d.use:SetText(ns.char.active == g.key and "In use" or "Use this guide")
	d.use:SetEnabled(ns.char.active ~= g.key)
	d.edit:SetEnabled(g.custom and true or false)
	d.delete:SetEnabled(g.custom and true or false)
	d.delete:SetText(confirmDelete == g.key and "Sure?" or "Delete")

	-- the route, cut at the stop
	local fit = math.floor((d:GetHeight() + d.routeTop - 4) / ROUTE_ROW)
	d.offset = math.max(0, math.min(d.offset or 0, #g.steps - fit))
	d.route:Reset()
	for i = d.offset + 1, math.min(#g.steps, d.offset + fit) do
		local step = g.steps[i]
		local row = d.route:Get()
		row:ClearAllPoints()
		row:SetPoint("TOPLEFT", 0, d.routeTop - (i - d.offset - 1) * ROUTE_ROW)
		local text = stepLabel(step)
		if step.kind == "craft" and not st.out[i] then
			text = text .. ("  x%d"):format(P.CraftsLeft(step, 0, ctx.target))
		end
		if st.out[i] then
			row:SetText(UI.Color({ 0.4, 0.4, 0.4 }, text .. "  (past your stop)"))
		elseif st.done[i] then
			row:SetText(UI.Color({ 0.35, 0.7, 0.35 }, text))
		elseif i == st.current then
			row:SetText(UI.Color("yellow", "> " .. text))
		else
			row:SetText(text)
		end
	end
	d.route:Finish()
end

local function makeRouteRow(parent)
	local t = UI.Text(parent, "small", { 0.9, 0.9, 0.9 })
	t:SetWidth(500)
	t:SetWordWrap(false)
	return t
end

-- Editor -------------------------------------------------------------------------------------

local function draftEnd()
	local hi
	for _, s in ipairs(draft.steps) do
		if s.to and (not hi or s.to > hi) then hi = s.to end
	end
	return hi
end

local function makeEditRow(parent)
	local r = CreateFrame("Frame", nil, parent)
	r:SetSize(500, EDIT_ROW - 2)
	local function num(field)
		return function(_, text)
			local s = draft.steps[r.index]
			if s then s[field] = tonumber(text) end
		end
	end
	r.from = UI.Edit(r, 34, true, num("from"))
	r.from:SetPoint("LEFT", 4, 0)
	r.to = UI.Edit(r, 34, true, num("to"))
	r.to:SetPoint("LEFT", 44, 0)
	r.recipe = UI.Text(r, "small", { 1, 1, 1 })
	r.recipe:SetPoint("LEFT", 86, 0)
	r.recipe:SetWidth(240)
	r.recipe:SetWordWrap(false)
	r.crafts = UI.Edit(r, 40, true, function(_, text)
		local s = draft.steps[r.index]
		local n = tonumber(text)
		if s and n then s.safe, s.expected = n, n end
	end)
	r.crafts:SetPoint("LEFT", 334, 0)
	local function move(delta)
		return function()
			local i, j = r.index, r.index + delta
			local list = draft.steps
			if list[j] then
				list[i], list[j] = list[j], list[i]
				refill = true
				W.Render()
			end
		end
	end
	r.up = UI.Button(r, "^", 24, 20, move(-1))
	r.up:SetPoint("LEFT", 382, 0)
	r.down = UI.Button(r, "v", 24, 20, move(1))
	r.down:SetPoint("LEFT", 408, 0)
	r.del = UI.Button(r, "x", 24, 20, function()
		table.remove(draft.steps, r.index)
		refill = true
		W.Render()
	end)
	r.del:SetPoint("LEFT", 434, 0)
	return r
end

local function addRecipe(info)
	local from = math.min(draftEnd() or draft.from or 1, 449)
	local to = math.min(from + 10, 450)
	draft.steps[#draft.steps + 1] = ns.Custom.StepFor(info, from, to)
	local e = win.editor
	e.offset = math.max(0, #draft.steps - 8)
	refill = true
	W.Render()
end

local function makePickRow(parent)
	local b = CreateFrame("Button", nil, parent)
	b:SetSize(240, 16)
	b:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
	b.text = UI.Text(b, "small", { 0.9, 0.9, 0.6 })
	b.text:SetPoint("LEFT", 2, 0)
	b.text:SetWidth(236)
	b.text:SetWordWrap(false)
	b:SetScript("OnClick", function(self) if self.info then addRecipe(self.info) end end)
	return b
end

local function renderEditor()
	local e = win.editor
	local fill = refill
	refill = false
	if fill then e.nameBox:SetText(draft.name or "") end
	e.prof:SetText(draft.profession .. (draftKey and "" or UI.Color("gray", "  (new)")))
	local fit = 8
	e.offset = math.max(0, math.min(e.offset or 0, #draft.steps - fit))
	e.rows:Reset()
	for i = e.offset + 1, math.min(#draft.steps, e.offset + fit) do
		local s = draft.steps[i]
		local r = e.rows:Get()
		r.index = i
		r:ClearAllPoints()
		r:SetPoint("TOPLEFT", 0, -46 - (i - e.offset - 1) * EDIT_ROW)
		local isCraft = s.kind == "craft" or s.kind == "disenchant"
		r.from:SetShown(isCraft)
		r.to:SetShown(isCraft)
		r.crafts:SetShown(s.kind == "craft")
		if fill or r.shown ~= s then
			if isCraft then
				r.from:SetText(s.from and tostring(s.from) or "")
				r.to:SetText(s.to and tostring(s.to) or "")
			end
			if s.kind == "craft" then r.crafts:SetText(tostring(s.safe or s.expected or "")) end
			r.shown = s
		end
		r.recipe:SetText(s.kind == "craft" and s.recipe or stepLabel(s))
		r.up:SetEnabled(i > 1)
		r.down:SetEnabled(i < #draft.steps)
	end
	e.rows:Finish()
	e.more:SetText(#draft.steps > fit and ("%d-%d of %d steps (mouse wheel)"):format(e.offset + 1,
		math.min(#draft.steps, e.offset + fit), #draft.steps) or (#draft.steps == 0 and "No steps yet: add recipes below." or ""))

	-- recipes from the open window of this profession
	e.picks:Reset()
	if ns.open and ns.open.profession == draft.profession then
		e.pickHint:SetText(("Add a recipe from your %s window:"):format(draft.profession))
		e.search:Show()
		local names = {}
		local q = search:lower()
		for name in pairs(ns.open.byName) do
			if q == "" or name:lower():find(q, 1, true) then names[#names + 1] = name end
		end
		table.sort(names)
		for i = 1, math.min(#names, 5) do
			local b = e.picks:Get()
			b.info = ns.open.byName[names[i]]
			b.text:SetText("+ " .. names[i])
			b:ClearAllPoints()
			b:SetPoint("TOPLEFT", 0, -342 - (i - 1) * 16)
		end
	else
		e.pickHint:SetText(("Open your %s window to add recipes to this guide."):format(draft.profession))
		e.search:Hide()
	end
	e.picks:Finish()
end

-- Share dialog -------------------------------------------------------------------------------

local function buildShare()
	local s = UI.Panel("CraftboundShare", UIParent, 480, 330)
	s:SetPoint("CENTER", 0, 40)
	s:SetFrameStrata("DIALOG")
	tinsert(UISpecialFrames, "CraftboundShare")
	s.title = UI.Text(s, "big", UI.GOLD)
	s.title:SetPoint("TOPLEFT", 12, -10)
	local close = CreateFrame("Button", nil, s, "UIPanelCloseButton")
	close:SetPoint("TOPRIGHT", -2, -2)
	local scroll = CreateFrame("ScrollFrame", "CraftboundShareScroll", s, "UIPanelScrollFrameTemplate")
	scroll:SetPoint("TOPLEFT", 12, -38)
	scroll:SetSize(430, 220)
	local box = CreateFrame("EditBox", nil, scroll)
	box:SetMultiLine(true)
	box:SetAutoFocus(false)
	box:SetFontObject("ChatFontNormal")
	box:SetWidth(420)
	box:SetScript("OnEscapePressed", function() s:Hide() end)
	scroll:SetScrollChild(box)
	s.box = box
	s.msg = UI.Text(s, "small", { 0.85, 0.85, 0.85 })
	s.msg:SetPoint("BOTTOMLEFT", 12, 40)
	s.msg:SetWidth(456)
	s.action = UI.Button(s, "Import", 100, 22, function()
		local g, err = ns.Share.Import(box:GetText())
		if not g then
			s.msg:SetText(UI.Color({ 1, 0.4, 0.3 }, "Could not import: " .. tostring(err) .. "."))
			return
		end
		local saved, why = ns.Custom.Add(g)
		if not saved then
			s.msg:SetText(UI.Color({ 1, 0.4, 0.3 }, "Could not import: " .. tostring(why) .. "."))
			return
		end
		s:Hide()
		if mode ~= "edit" then selected = saved.key end
		W.Show()
		message(("Imported %s · %s (%d steps)."):format(saved.profession, saved.name, #saved.steps))
	end)
	s.action:SetPoint("BOTTOMRIGHT", -12, 10)
	return s
end

function W.ShowShare(exportText)
	share = share or buildShare()
	if exportText then
		share.title:SetText("Export guide")
		share.box:SetText(exportText)
		share.msg:SetText("Press Ctrl+C to copy, then paste it anywhere: Discord, a forum, a whisper. Others import it with Import in their Craftbound window.")
		share.action:Hide()
		share:Show()
		share.box:SetFocus()
		share.box:HighlightText()
	else
		share.title:SetText("Import guide")
		share.box:SetText("")
		share.msg:SetText("Paste a guide (Ctrl+V, it starts with CB1:) and press Import. It becomes one of your custom guides.")
		share.action:Show()
		share:Show()
		share.box:SetFocus()
	end
	return share
end

-- Actions ------------------------------------------------------------------------------------

function W.Edit(key)
	local g = P.Find(key)
	if not (g and g.custom) then return end
	selected, draftKey, mode = key, key, "edit"
	draft = ns.Custom.Copy(g)
	win.editor.offset = 0
	refill = true
	message("")
	W.Render()
end

function W.NewGuide()
	W.Show()
	if not ns.open then
		message("Open a profession window first (the new guide is for that profession), or copy a guide and edit it.", true)
		return
	end
	if mode == "edit" then return message("Save or cancel the guide you are editing first.", true) end
	draft, draftKey, mode = ns.Custom.Draft(ns.open.profession), nil, "edit"
	win.editor.offset = 0
	refill = true
	message("")
	W.Render()
end

-- A step the editor would lose on save (Sanitize drops it): say which, instead.
local function badStep()
	for i, s in ipairs(draft.steps) do
		if s.kind == "craft" or s.kind == "disenchant" then
			if not (s.from and s.to and s.from >= 0 and s.to > s.from and s.to <= 450) then
				return ("Step %d (%s): From and To must be skills from 0 to 450, To above From."):format(i, s.recipe or s.kind)
			end
		end
	end
end

-- The editor on an unsaved copy of a guide (for /craft shots): nothing is stored.
function W.Preview(guide)
	W.Show()
	draft = ns.Custom.Copy(guide)
	draft.key, draft.custom, draft.id = nil, nil, nil
	draftKey, mode = nil, "edit"
	win.editor.offset = 0
	refill = true
	message("")
	W.Render()
end

-- Leave the editor without saving.
function W.CancelEdit()
	if mode ~= "edit" then return end
	mode, draft, draftKey = "details", nil, nil
	message("")
	W.Render()
end

local function save()
	draft.name = win.editor.nameBox:GetText()
	if #draft.steps == 0 then return message("Add at least one step first.", true) end
	local bad = badStep()
	if bad then return message(bad, true) end
	local g, err
	if draftKey then g, err = ns.Custom.Save(draftKey, draft) else g, err = ns.Custom.Add(draft) end
	if not g then return message("Can't save: " .. tostring(err) .. ".", true) end
	selected, mode, draft, draftKey = g.key, "details", nil, nil
	message(("Saved %s."):format(g.name))
	W.Render()
end

-- Build --------------------------------------------------------------------------------------

local function buildDetails(f)
	local d = CreateFrame("Frame", nil, f)
	d:SetPoint("TOPLEFT", 262, -46)
	d:SetSize(506, HEIGHT - 76)
	d.name = UI.Text(d, "big", UI.GOLD)
	d.name:SetPoint("TOPLEFT", 0, 0)
	d.sub = UI.Text(d, "small", { 0.7, 0.7, 0.7 })
	d.sub:SetPoint("TOPLEFT", 0, -22)
	d.skill = UI.Text(d, nil, { 1, 1, 1 })
	d.skill:SetPoint("TOPLEFT", 0, -40)
	d.skill:SetWidth(500)
	local stop = UI.Text(d, nil, UI.GOLD)
	stop:SetPoint("TOPLEFT", 0, -68)
	stop:SetText("Stop at")
	d.targets = {}
	for k = 1, 4 do
		local b = UI.Button(d, "", 96, 22, function(self)
			ns.SetTarget(selected, self.target)
		end)
		b:SetPoint("TOPLEFT", 60 + (k - 1) * 106, -64)
		b.cost = UI.Text(d, "small", { 1, 1, 1 }, "CENTER")
		b.cost:SetPoint("TOP", b, "BOTTOM", 0, -3)
		b.cost:SetWidth(104)
		UI.Tooltip(b, function(tip)
			tip:AddLine(("Stop at %d"):format(b.target or 0))
			tip:AddLine("The route, the shopping list and the progress bar end here. The cost is what you still need to buy from your skill now, at remembered prices, plus recipes still to learn.", 1, 1, 1, true)
		end)
		d.targets[k] = b
	end
	d.prices = UI.Text(d, "small", { 0.65, 0.65, 0.65 })
	d.prices:SetPoint("TOPLEFT", 0, -122)
	d.prices:SetWidth(500)
	d.use = UI.Button(d, "Use this guide", 116, 22, function()
		if ns.SetActive(selected) then
			local g = P.Find(selected)
			message(("Now following %s · %s."):format(g.profession, g.name))
			if ns.ShowTracker then ns.ShowTracker() end
		end
	end)
	d.use:SetPoint("TOPLEFT", 0, -142)
	d.copy = UI.Button(d, "Copy and edit", 110, 22, function()
		local g = ns.Custom.CopyOf(P.Find(selected))
		if g then W.Edit(g.key) end
	end)
	d.copy:SetPoint("LEFT", d.use, "RIGHT", 6, 0)
	d.edit = UI.Button(d, "Edit", 70, 22, function() W.Edit(selected) end)
	d.edit:SetPoint("LEFT", d.copy, "RIGHT", 6, 0)
	d.delete = UI.Button(d, "Delete", 70, 22, function()
		if confirmDelete ~= selected then
			confirmDelete = selected
			W.Render()
			return
		end
		local g = P.Find(selected)
		ns.Custom.Delete(selected)
		message(("Deleted %s."):format(g and g.name or "the guide"))
		selected, confirmDelete = nil, nil
		W.Render()
	end)
	d.delete:SetPoint("LEFT", d.edit, "RIGHT", 6, 0)
	d.export = UI.Button(d, "Export", 80, 22, function()
		W.ShowShare(ns.Share.Export(P.Find(selected)))
	end)
	d.export:SetPoint("LEFT", d.delete, "RIGHT", 6, 0)
	local route = UI.Text(d, nil, UI.GOLD)
	route:SetPoint("TOPLEFT", 0, -176)
	route:SetText("Route")
	d.routeTop = -194
	d.route = UI.Pool(d, makeRouteRow)
	wheel(d, "offset")
	return d
end

local function buildEditor(f)
	local e = CreateFrame("Frame", nil, f)
	e:SetPoint("TOPLEFT", 262, -46)
	e:SetSize(506, HEIGHT - 76)
	local nameLabel = UI.Text(e, nil, UI.GOLD)
	nameLabel:SetPoint("TOPLEFT", 0, -4)
	nameLabel:SetText("Name")
	e.nameBox = UI.Edit(e, 220, false, function(_, text) draft.name = text end)
	e.nameBox:SetMaxLetters(60)
	e.nameBox:SetPoint("TOPLEFT", 48, 0)
	e.prof = UI.Text(e, nil, { 1, 1, 1 })
	e.prof:SetPoint("TOPLEFT", 286, -4)
	local head = UI.Text(e, "small", { 0.7, 0.7, 0.7 })
	head:SetPoint("TOPLEFT", 4, -30)
	head:SetText("From      To         Recipe                                                                   Crafts")
	e.rows = UI.Pool(e, makeEditRow)
	e.more = UI.Text(e, "small", { 0.65, 0.65, 0.65 })
	e.more:SetPoint("TOPLEFT", 4, -46 - 8 * EDIT_ROW - 4)
	wheel(e, "offset")
	e.pickHint = UI.Text(e, nil, UI.GOLD)
	e.pickHint:SetPoint("TOPLEFT", 0, -298)
	e.pickHint:SetWidth(500)
	e.search = UI.Edit(e, 200, false, function(_, text)
		search = text
		W.Render()
	end)
	e.search:SetPoint("TOPLEFT", 6, -316)
	UI.Tooltip(e.search, function(tip) tip:AddLine("Search the recipes of the open window") end)
	e.picks = UI.Pool(e, makePickRow)
	local help = UI.Text(e, "small", { 0.65, 0.65, 0.65 })
	help:SetPoint("TOPLEFT", 260, -320)
	help:SetWidth(240)
	help:SetText("A new step starts where the last one ends. Set From and To to the skill range, and Crafts to how many you shop for. Craftbound follows your real skill either way.")
	e.save = UI.Button(e, "Save", 90, 22, save)
	e.save:SetPoint("BOTTOMRIGHT", -96, 0)
	e.cancel = UI.Button(e, "Cancel", 90, 22, function()
		mode, draft, draftKey = "details", nil, nil
		message("")
		W.Render()
	end)
	e.cancel:SetPoint("BOTTOMRIGHT", 0, 0)
	return e
end

local function build()
	local f = UI.Panel("CraftboundWindow", UIParent, WIDTH, HEIGHT)
	local pos = ns.char.window
	if pos then f:SetPoint(pos.point, UIParent, pos.point, pos.x, pos.y) else f:SetPoint("CENTER") end
	f:SetFrameStrata("HIGH")
	UI.Movable(f, function() return ns.char end, "window")
	tinsert(UISpecialFrames, "CraftboundWindow")
	f.title = UI.Text(f, "big", UI.GOLD)
	f.title:SetPoint("TOPLEFT", 12, -10)
	f.title:SetText("Craftbound")
	f.logo = UI.TitleLogo(f, f.title, 22)
	local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
	close:SetPoint("TOPRIGHT", -2, -2)
	f.import = UI.Button(f, "Import", 80, 22, function() W.ShowShare() end)
	f.import:SetPoint("TOPRIGHT", -34, -8)
	f.new = UI.Button(f, "New guide", 96, 22, W.NewGuide)
	f.new:SetPoint("RIGHT", f.import, "LEFT", -6, 0)
	UI.Divider(f, -38)
	local line = f:CreateTexture(nil, "ARTWORK")
	line:SetColorTexture(0.45, 0.33, 0.15, 0.6)
	line:SetWidth(1)
	line:SetPoint("TOPLEFT", 252, -42)
	line:SetPoint("BOTTOMLEFT", 252, 28)

	f.left = CreateFrame("Frame", nil, f)
	f.left:SetPoint("TOPLEFT", 8, -44)
	f.left:SetSize(240, HEIGHT - 74)
	f.left.rows = UI.Pool(f.left, makeGuideRow)
	wheel(f.left, "offset")

	f.empty = UI.Text(f, nil, { 0.8, 0.8, 0.8 })
	f.empty:SetPoint("TOPLEFT", 262, -50)
	f.empty:SetWidth(500)
	f.empty:SetText("Pick a guide on the left. Copy one to make it your own, or start a new guide with your profession window open. Import a guide someone shared with Import.")

	f.details = buildDetails(f)
	f.editor = buildEditor(f)
	win = f
	f.msg = UI.Text(f, "small", { 0.85, 0.85, 0.85 })
	f.msg:SetPoint("BOTTOMLEFT", 12, 9)
	f.msg:SetWidth(WIDTH - 24)
	f:SetScript("OnShow", function() W.Render() end)
	return f
end

-- Render -------------------------------------------------------------------------------------

function W.Render()
	if not win or not win:IsShown() then return end
	if selected and not P.Find(selected) then selected = nil end
	if mode == "edit" and not draft then mode = "details" end
	renderList()
	local g = selected and P.Find(selected)
	win.details:SetShown(mode == "details" and g ~= nil)
	win.editor:SetShown(mode == "edit")
	win.empty:SetShown(mode == "details" and g == nil)
	if mode == "edit" then renderEditor()
	elseif g then renderDetails(g) end
end

function W.Show(key)
	win = win or build()
	if key and mode ~= "edit" then selected = key end
	selected = selected or ns.char.active
	win:Show()
	W.Render()
	return win
end

function W.Toggle()
	if win and win:IsShown() then win:Hide() else W.Show() end
end

ns.On("CB_REFRESH", W.Render)
