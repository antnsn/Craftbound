-- Use another recipe: right-click a step in the route list (the profession panel) and pick any
-- learned recipe of the open window that still gives skill-ups. The step then uses it everywhere:
-- the panel, Craft, the tracker and the shopping list (they all read ns.ActiveGuide()). Kept per
-- character and guide: GuideState(key).swaps[step index] = recipe name.
local _, ns = ...

local UI = ns.UI

local function swapsOf(key)
	return key and ns.char and ns.GuideState(key).swaps -- GuideState drops them when the guide was edited
end

-- the guide with this character's picks in place (the same guide when there are none)
function ns.WithSwaps(guide)
	local swaps = guide and swapsOf(guide.key)
	if not swaps or next(swaps) == nil then return guide end
	local d = {}
	for k, v in pairs(guide) do d[k] = v end
	d.steps = {}
	for i, s in ipairs(guide.steps) do
		local name = swaps[i]
		if name and s.kind == "craft" and name ~= s.recipe then
			local c = {}
			for k, v in pairs(s) do c[k] = v end
			c.recipe = name
			c.mats = (ns.db.recipes[name] or {}).mats or {}
			-- what the guide's recipe needed (a rod, an anvil) is not the pick's: the window knows
			-- (how many the old one made too: the shopping list counts the pick as one per craft)
			c.source, c.alts, c.tools, c.station, c.makes = nil, nil, nil, nil, nil
			c.swappedFrom = s.recipe
			c.note = ("Your pick, instead of %s. Right-click the step in the route list to change it."):format(s.recipe)
			d.steps[i] = c
		else
			d.steps[i] = s
		end
	end
	return d
end

local baseActive = ns.ActiveGuide
function ns.ActiveGuide()
	return ns.WithSwaps(baseActive())
end

-- every recipe name this character picked for a guide (Profession.lua remembers their reagents)
function ns.SwapNames(key)
	local out = {}
	for _, name in pairs(swapsOf(key) or {}) do out[#out + 1] = name end
	return out
end

function ns.SetSwap(key, index, name)
	local guide = key and ns.Planner.Find(key)
	if not guide then return end
	local gs = ns.GuideState(key)
	gs.swaps = gs.swaps or {}
	gs.swaps[index] = name
	if ns.open then ns.ScanOpen() end -- the pick's reagents
	ns.Refresh()
end

-- The picker ------------------------------------------------------------------------------

local picker

local function candidates(exclude)
	local out = {}
	for name, r in pairs(ns.open and ns.open.byName or {}) do
		local d = r.relativeDifficulty
		if r.learned ~= false and type(d) == "number" and d <= 2 and not exclude[name] then
			out[#out + 1] = r
		end
	end
	table.sort(out, function(a, b)
		if a.relativeDifficulty ~= b.relativeDifficulty then return a.relativeDifficulty < b.relativeDifficulty end
		return a.name < b.name
	end)
	return out
end

local function makeRow(parent)
	local b = CreateFrame("Button", nil, parent)
	b:SetSize(264, 16)
	b.text = UI.Text(b, "small")
	b.text:SetPoint("LEFT", 2, 0)
	b.text:SetWidth(220)
	b.text:SetWordWrap(false)
	b.count = UI.Text(b, "small", { 0.7, 0.7, 0.7 }, "RIGHT")
	b.count:SetPoint("RIGHT", -2, 0)
	b:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
	b:SetScript("OnClick", function(self)
		picker:Hide()
		-- only for the guide and window it was opened for
		local guide = baseActive()
		if not (ns.open and guide and guide.key == picker.key) then return end
		ns.SetSwap(picker.key, picker.index, self.back and nil or self.recipe)
	end)
	return b
end

local FIT = 16

function ns.OpenSwapPicker(index, offset)
	local panel = ns.professionPanel
	local guide = baseActive()
	local step = guide and guide.steps[index]
	if not (panel and step and step.kind == "craft") then return end
	if not ns.open then ns.Print("Open your profession window to pick a recipe.") return end
	if not picker then
		picker = UI.Panel("CraftboundSwapPicker", panel, 280, 300)
		picker:SetFrameStrata("DIALOG")
		picker:SetPoint("TOPLEFT", panel, "TOPLEFT", 10, -60)
		picker.title = UI.Text(picker, nil, UI.GOLD)
		picker.title:SetPoint("TOPLEFT", 8, -8)
		picker.title:SetWidth(240)
		picker.close = UI.Button(picker, "x", 20, 20, function() picker:Hide() end)
		picker.close:SetPoint("TOPRIGHT", -4, -4)
		picker.empty = UI.Text(picker, "small", { 0.8, 0.8, 0.8 })
		picker.empty:SetWidth(264)
		picker.rows = UI.Pool(picker, makeRow)
		picker:EnableMouseWheel(true)
		picker:SetScript("OnMouseWheel", function(self, delta)
			ns.OpenSwapPicker(self.index, (self.offset or 0) - delta * 3)
		end)
		panel:HookScript("OnHide", function() picker:Hide() end) -- a closed window takes it along
	end
	picker.index, picker.key = index, guide.key
	local current = (swapsOf(guide.key) or {})[index]
	picker.title:SetText(("Step %d-%d: craft instead"):format(step.from, step.to))
	picker.rows:Reset()
	local prev
	local function place(row)
		row:ClearAllPoints()
		if prev then row:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, 0) else row:SetPoint("TOPLEFT", 8, -30) end
		prev = row
	end
	if current then
		local row = picker.rows:Get()
		row.back, row.recipe = true, nil
		row.text:SetText(UI.Color(UI.GOLD, "Back to " .. step.recipe))
		row.count:SetText("")
		place(row)
	end
	local list = candidates({ [step.recipe] = true, [current or ""] = true })
	local first = math.max(0, math.min(offset or 0, #list - FIT))
	picker.offset = first
	for i = first + 1, math.min(#list, first + FIT) do
		local r = list[i]
		local row = picker.rows:Get()
		row.back, row.recipe = nil, r.name
		row.text:SetText(UI.Color(UI.DIFFICULTY[r.relativeDifficulty], r.name))
		local can = C_TradeSkillUI.GetCraftableCount and C_TradeSkillUI.GetCraftableCount(r.recipeID)
		row.count:SetText(type(can) == "number" and can > 0 and ("x" .. can) or "")
		place(row)
	end
	picker.rows:Finish()
	picker.empty:ClearAllPoints()
	picker.empty:SetPoint("TOPLEFT", prev or picker.title, "BOTTOMLEFT", 0, -6)
	picker.empty:SetText(#list == 0 and "No other learned recipe gives skill-ups right now."
		or (#list > FIT and ("%d-%d of %d: mouse wheel for more.\n"):format(first + 1, math.min(#list, first + FIT), #list) or "")
		.. "Orange and yellow give a skill-up every craft; green only sometimes. The route's craft counts stay the guide's estimate.")
	local rows = picker.rows.used
	local note = picker.empty.GetStringHeight and picker.empty:GetStringHeight() or 0
	picker:SetHeight(30 + rows * 16 + 6 + math.max(type(note) == "number" and note or 0, 28) + 10)
	picker:Show()
end
