-- Profession: reads skills and recipes through C_TradeSkillUI, crafts, and docks the route panel
-- to Blizzard's profession window (ProfessionsFrame).
--
-- Crafting is a click on our button or the "Craft next" key binding, both hardware events.
-- Enchants go on the sidebar's item or the equipped one (Enchants.lua); the game's "replace the
-- enchant?" and "bind it?" questions are answered in the same press when they are ours to answer,
-- else by the next press of the key or the button.
local _, ns = ...

local UI = ns.UI
local P = ns.Planner

-- Skill line IDs, so other client languages still find the right guide.
ns.SKILL_LINES = {
	[171] = "Alchemy", [164] = "Blacksmithing", [333] = "Enchanting", [202] = "Engineering",
	[182] = "Herbalism", [165] = "Leatherworking", [186] = "Mining", [393] = "Skinning",
	[197] = "Tailoring", [185] = "Cooking", [129] = "First Aid", [356] = "Fishing",
}

-- Skills, outside the window -------------------------------------------------------------

function ns.ReadProfessions()
	if not GetProfessions then return end
	local list = { GetProfessions() }
	for _, idx in pairs(list) do
		local name, _, rank, maxRank, _, _, skillLine = GetProfessionInfo(idx)
		local prof = ns.SKILL_LINES[skillLine] or name
		if type(prof) == "string" and type(rank) == "number" then
			ns.NoteSkill(prof, rank, type(maxRank) == "number" and maxRank or nil)
		end
	end
end

-- The open window ---------------------------------------------------------------------------

ns.open = nil -- { profession, byName = { [recipe name] = recipeInfo } }

local function isOwnProfession()
	local T = C_TradeSkillUI
	if T.IsTradeSkillLinked and T.IsTradeSkillLinked() then return false end
	if T.IsTradeSkillGuild and T.IsTradeSkillGuild() then return false end
	if T.IsNPCCrafting and T.IsNPCCrafting() then return false end
	return true
end

-- Real reagents from the recipe's schematic, named from the guide where the IDs match.
local function readMats(recipeID, guideMats)
	local ok, sch = pcall(C_TradeSkillUI.GetRecipeSchematic, recipeID, false)
	if not ok or not sch or not sch.reagentSlotSchematics then return nil, nil end
	local names = {}
	for _, m in ipairs(guideMats or {}) do
		if m.id then names[m.id] = m.name end
	end
	local mats = {}
	for _, slot in ipairs(sch.reagentSlotSchematics) do
		local r = slot.reagents and slot.reagents[1]
		if r and r.itemID and slot.required ~= false then
			local name = names[r.itemID] or (C_Item.GetItemNameByID and C_Item.GetItemNameByID(r.itemID))
			if not name and C_Item.RequestLoadItemDataByID then C_Item.RequestLoadItemDataByID(r.itemID) end
			mats[#mats + 1] = { id = r.itemID, name = name or ("item:" .. r.itemID), qty = slot.quantityRequired or 1 }
			if name then ns.LearnItem(name, r.itemID) end
		end
	end
	return (#mats > 0) and mats or nil, sch
end
ns.ReadMats = function(recipeID) return (readMats(recipeID)) end

-- Read the open profession: skill, every recipe by name, and the real reagents of the guide's.
function ns.ScanOpen()
	local T = C_TradeSkillUI
	if not T or not T.GetBaseProfessionInfo then return end
	if T.IsTradeSkillReady and not T.IsTradeSkillReady() then return end
	if not isOwnProfession() then
		ns.open = nil
		return
	end
	local info = T.GetBaseProfessionInfo()
	if type(info) ~= "table" or type(info.professionID) ~= "number" then return end
	local prof = ns.SKILL_LINES[info.professionID] or info.professionName
	if info.skillLevel then ns.NoteSkill(prof, info.skillLevel, info.maxSkillLevel) end

	local byName, seen = {}, {}
	local function add(ids)
		for _, id in ipairs(ids or {}) do
			if not seen[id] then
				seen[id] = true
				local r = T.GetRecipeInfo(id)
				if r and r.name then
					byName[r.name] = r
					if r.learned then ns.char.known[r.name] = true end
				end
			end
		end
	end
	add(T.GetAllRecipeIDs())
	if T.GetFilteredRecipeIDs then add(T.GetFilteredRecipeIDs()) end
	ns.open = { profession = prof, byName = byName }

	-- this profession's guide becomes the active one
	local guides = P.ForProfession(prof)
	local active = ns.ActiveGuide()
	if guides[1] and (not active or active.profession ~= prof) then ns.SetActive(guides[1].key) end

	-- remember the real reagents of every recipe the guides use, and of the character's picks
	local function remember(name, guideMats)
		local r = name and byName[name]
		if not r then return end
		local mats, sch = readMats(r.recipeID, guideMats)
		local rec = ns.db.recipes[name] or {}
		rec.id = r.recipeID
		if mats then rec.mats = mats end
		rec.enchant = sch and Enum.TradeskillRecipeType and sch.recipeType == Enum.TradeskillRecipeType.Enchant or nil
		ns.db.recipes[name] = rec
	end
	for _, g in ipairs(guides) do
		for _, s in ipairs(g.steps) do remember(s.recipe, s.mats) end
		for _, name in ipairs(ns.SwapNames(g.key)) do remember(name) end
	end
	ns.Refresh()
end

-- The live recipe info for a guide recipe in the open window (nil when closed or unknown).
function ns.OpenRecipe(name)
	return ns.open and ns.open.byName[name]
end

function ns.SelectRecipe(name)
	local r = ns.OpenRecipe(name)
	if not r then return false end
	local page = ProfessionsFrame and ProfessionsFrame.CraftingPage
	if page and page.SelectRecipe then
		local fresh = C_TradeSkillUI.GetRecipeInfo(r.recipeID) or r
		if pcall(page.SelectRecipe, page, fresh) then return true end
	end
	if C_TradeSkillUI.OpenRecipe then pcall(C_TradeSkillUI.OpenRecipe, r.recipeID) end
	return true
end

-- Where to learn a step's recipe, from the guide's source.
-- The vendors of a recipe that serve this character: own faction and neutral, at most two.
-- Returns their names and whether those shown sell it in limited stock.
local function vendorsFor(src)
	local side = UnitFactionGroup and UnitFactionGroup("player")
	local t, more, limited = {}, false, false
	for _, v in ipairs(src.vendors) do
		if not v.side or not side or v.side == side then
			if #t == 2 then more = true break end
			t[#t + 1] = v.npc .. (v.location and (" (" .. v.location .. ")") or "")
			limited = limited or v.limited or false
		end
	end
	if #t == 0 then return nil end
	return table.concat(t, " or ") .. (more and ", and other vendors" or ""), limited
end

function ns.LearnHint(s)
	local src = s.source or {}
	if src.kind == "known" then
		return ("%s is a starting recipe: learn it from your trainer."):format(s.recipe)
	elseif src.kind == "quest" then
		return ("%s is a quest reward."):format(s.recipe)
	elseif src.kind == "drop" then
		return ("The %s recipe drops from mobs; buy it at the auction house."):format(s.recipe)
	end
	if src.kind == "vendor" and src.vendors then
		local who, limited = vendorsFor(src)
		local rep = src.rep and (" Needs " .. src.rep .. ".") or ""
		if not who then
			return ("The %s recipe is only sold to the other faction; buy it at the auction house."):format(s.recipe) .. rep
		end
		return ("Buy the %s recipe from %s%s."):format(s.recipe, who, limited and ", limited stock" or "") .. rep
	end
	if src.kind == "vendor" and src.npc then
		return ("Buy the %s recipe from %s%s%s."):format(s.recipe, src.npc,
			src.location and (" (" .. src.location .. ")") or "",
			src.limited and ", limited stock" or "") .. (src.rep and (" Needs " .. src.rep .. ".") or "")
	end
	return ("Learn %s at your trainer%s."):format(s.recipe, src.cost and (" (" .. ns.Money(src.cost) .. ")") or "")
end

-- Crafting ----------------------------------------------------------------------------------

local replacePending -- the game asked "replace the enchant?" after our CraftEnchant
local bindPending    -- ... or "bind it to you?" (an item in the bags)
local answerUntil, bindUntil -- our last enchant's questions are ours to answer until then

-- Two kinds of "replace the enchant?": REPLACE_TRADESKILL_ENCHANT for a profession window enchant
-- (what Forever asks for ours), REPLACE_ENCHANT for the older item path. Each has its own answer.
local REPLACE = {
	REPLACE_TRADESKILL_ENCHANT = "ReplaceTradeskillEnchant",
	REPLACE_ENCHANT = "ReplaceEnchant",
}
local replaceKind = "REPLACE_ENCHANT" -- the event that asked last
local function replaceCall() C_Item[REPLACE[replaceKind]]() end -- errors when missing: not answered
local function hideReplace() if StaticPopup_Hide then StaticPopup_Hide(replaceKind) end end
local function hideBind() if StaticPopup_Hide then StaticPopup_Hide("BIND_ENCHANT") StaticPopup_Hide("ENCHANT_BIND") end end

local function answerReplace()
	replacePending = nil
	replaceCall()
	hideReplace()
end
local function answerBind()
	bindPending = nil
	C_Item.BindEnchant()
	hideBind()
end

-- The one exception to "only from a press": the game asks a moment after the press, and the
-- player chose to skip that question (a sidebar item, or Overwrite on). Answer it right away;
-- if the client blocks that (ADDON_ACTION_BLOCKED), the question stays for the next press and
-- Craftbound stops trying (settings.answerBlocked).
-- answers tried this frame; a block reported meanwhile counts against all of them (we can't tell
-- which call the client meant), so each one's question stays for the next press
local attempts = {}
ns.On("ADDON_ACTION_BLOCKED", function(addon)
	if addon ~= ns.name then return end
	for _, a in ipairs(attempts) do a.blocked = true end
end)
-- The questions come after our cast: it done, they arrive within moments; it failed or was
-- cancelled, any later question is the player's own.
local AFTER_CAST = 3
ns.On("UNIT_SPELLCAST_SUCCEEDED", function(unit)
	if unit ~= "player" then return end
	local soon = GetTime() + AFTER_CAST
	if answerUntil then answerUntil = math.min(answerUntil, soon) end
	if bindUntil then bindUntil = math.min(bindUntil, soon) end
end)
for _, e in ipairs({ "UNIT_SPELLCAST_FAILED", "UNIT_SPELLCAST_INTERRUPTED" }) do
	ns.On(e, function(unit) if unit == "player" then answerUntil, bindUntil = nil, nil end end)
end

local function answerNow(until_, call, hide, keep)
	if not until_ or GetTime() > until_ or ns.db.settings.answerBlocked then
		-- opted in, yet the game asks: say why it stays up
		if ns.db.settings.overwriteEnchants or next(ns.char.enchantTargets) then
			ns.Print(ns.db.settings.answerBlocked
				and "the game blocked answering for you earlier: press Craft (or your key) to answer."
				or "this enchant didn't come from Craftbound's Craft button or key, so the game's question is yours.")
		end
		return false
	end
	local a = { keep = keep, hide = hide }
	attempts[#attempts + 1] = a
	if not pcall(call) then a.blocked = true end
	if #attempts == 1 then
		C_Timer.After(0, function() -- after the game has shown its questions
			local list = attempts
			attempts = {}
			local any = false
			for _, x in ipairs(list) do any = any or x.blocked end
			for _, x in ipairs(list) do
				if any then x.keep() else x.hide() end
			end
			if any then
				ns.db.settings.answerBlocked = true
				ns.Refresh()
			end
		end)
	end
	return true
end

for event in pairs(REPLACE) do
	ns.On(event, function()
		local at = GetTime()
		replaceKind, replacePending = event, at
		local until_ = answerUntil
		answerUntil = nil -- one answer per enchant of ours
		if answerNow(until_, replaceCall, hideReplace, function() replacePending = at end) then
			replacePending = nil
		end
	end)
end
ns.On("BIND_ENCHANT", function()
	local at = GetTime()
	bindPending = at
	local until_ = bindUntil
	bindUntil = nil
	if answerNow(until_, C_Item.BindEnchant, hideBind, function() bindPending = at end) then
		bindPending = nil
	end
end)
-- is the game's question still up (asked in the last 30 s)? The bind dialog's name differs between
-- client versions: either counts.
local function asking(at, ...)
	if not at or GetTime() - at >= 30 then return false end
	if not StaticPopup_Visible then return true end
	for i = 1, select("#", ...) do
		if StaticPopup_Visible((select(i, ...))) then return true end
	end
	return false
end

-- Does the character have a tool (by name), or one of the items that serve as it (a better hammer)?
function ns.HasTool(guide, tool, ctx)
	if ctx.have({ id = ns.KnownIDs[tool], name = tool }) > 0 then return true end
	for _, s in ipairs(guide and guide.steps or {}) do
		if s.kind == "tool" and s.recipe == tool then
			for _, id in ipairs(s.items or {}) do
				if ctx.have({ id = id }) > 0 then return true end
			end
		end
	end
	return false
end

-- How to learn a part's recipe (grinding stones, blasting powder).
local function partLearnHint(short)
	local src = short.part.source or {}
	return ("Learn %s at your trainer%s to make the %s."):format(short.part.recipe,
		src.cost and (" (" .. ns.Money(src.cost) .. ")") or "", short.name)
end

-- The part to make first for these reagents, going into a part's own parts when it can't be
-- made yet (Unstable Trigger needs Solid Blasting Powder). Returns a plan, or nil and why not.
local function partPlan(guide, mats, room, ctx, depth)
	local why
	for _, m in ipairs(mats or {}) do
		local short = P.PartShort(guide, m, (m.qty or 1) * room, ctx, ns.BagCount)
		local pr = short and ns.OpenRecipe(short.part.recipe)
		if short and (not pr or pr.learned == false) then
			why = why or partLearnHint(short)
		elseif pr then
			local pc = C_TradeSkillUI.GetCraftableCount and C_TradeSkillUI.GetCraftableCount(pr.recipeID)
			if type(pc) == "number" and pc > 0 then
				local pn = math.min(short.crafts, pc)
				return { label = ("Make %d %s"):format(pn * (short.part.makes or 1), short.name), enabled = true,
					part = short.name, run = function()
						ns.SelectRecipe(short.part.recipe)
						C_TradeSkillUI.CraftRecipe(pr.recipeID, pn)
					end }
			elseif depth < 3 then
				local plan, sub = partPlan(guide, short.part.mats, short.crafts, ctx, depth + 1)
				if plan then return plan end
				why = why or sub
			end
		end
	end
	return nil, why
end

-- What one press of Craft does right now: returns a plan { label, enabled, reason, run }.
function ns.CraftPlan()
	if asking(replacePending, replaceKind) then
		return { label = "Replace enchant", enabled = true, run = answerReplace }
	end
	if asking(bindPending, "BIND_ENCHANT", "ENCHANT_BIND") then
		return { label = "Bind and enchant", enabled = true, run = answerBind }
	end
	local st, ctx = ns.Status()
	if not st then return { label = "Craft", enabled = false, reason = "No guide picked (/craft guide)." } end
	local s = st.step
	if not s or (s.kind ~= "craft" and s.kind ~= "tool") or s.buy then
		return { label = "Craft", enabled = false, reason = P.Describe(s, st.left) }
	end
	if not ns.open then
		return { label = "Craft", enabled = false, reason = "Open your profession window." }
	end
	local r = ns.OpenRecipe(s.recipe)
	if not r then
		return { label = "Craft", enabled = false, reason = s.recipe .. " is not in this window." }
	end
	if r.learned == false then
		return { label = "Craft", enabled = false, reason = ns.LearnHint(s) }
	end
	if s.swappedFrom and r.relativeDifficulty == 3 then
		return { label = "Craft", enabled = false, reason = ("%s is grey now: no more skill-ups. Right-click the step in the route list to pick another."):format(s.recipe) }
	end
	-- each craft gives at most one point: never craft past the rank's cap
	local room = st.left
	if ctx.maxSkill and s.kind == "craft" then
		room = math.min(room, ctx.maxSkill - ctx.skill)
		if room <= 0 then
			return { label = "Craft", enabled = false, reason = ("You are at the cap (%d): train the next rank first."):format(ctx.maxSkill) }
		end
	end
	-- parts the step needs (a grinding stone, a trigger): make those first
	local guide = ns.ActiveGuide()
	local partWhy
	if guide then
		local plan
		plan, partWhy = partPlan(guide, ns.LiveMats(s.recipe) or s.mats, room, ctx, 1)
		if plan then return plan end
	end
	local can = C_TradeSkillUI.GetCraftableCount and C_TradeSkillUI.GetCraftableCount(r.recipeID)
	if type(can) ~= "number" then can = 0 end
	if can <= 0 then
		local away = ns.ElsewhereFor(ns.LiveMats(s.recipe) or s.mats, 1)
		if #away > 0 then
			return { label = "Craft", enabled = false, reason = "Fetch them first: " .. ns.ElsewhereText(away) .. "." }
		end
		return { label = "Craft", enabled = false, reason = partWhy or "Missing reagents: see the list below or /craft list." }
	end
	local rec = ns.db.recipes[s.recipe] or {}
	if rec.enchant then
		return { label = ("Enchant (%d left)"):format(st.left), enabled = true, run = function()
			local loc, answer, inBags = ns.EnchantTarget(s.recipe)
			if loc and loc:IsValid() and C_TradeSkillUI.CraftEnchant then
				replacePending, bindPending = nil, nil
				-- until our cast is done (a few seconds after it, see UNIT_SPELLCAST_SUCCEEDED)
				answerUntil = answer and GetTime() + 60 or nil
				bindUntil = inBags and GetTime() + 60 or nil
				C_TradeSkillUI.CraftEnchant(r.recipeID, 1, nil, loc)
				-- (asked while the cast started: the event handlers above answered already)
			else
				C_TradeSkillUI.CraftRecipe(r.recipeID, 1) -- the game asks for a target
			end
		end }
	end
	local n = math.min(room, can)
	return { label = ("Craft %d"):format(n), enabled = true, run = function()
		ns.SelectRecipe(s.recipe)
		C_TradeSkillUI.CraftRecipe(r.recipeID, n)
	end }
end

function ns.CraftNext()
	if InCombatLockdown() then return end
	local plan = ns.CraftPlan()
	if plan.enabled and plan.run then
		plan.run()
	elseif plan.reason then
		ns.Print(plan.reason)
	end
end

-- Key binding (Bindings.xml)
BINDING_HEADER_CRAFTBOUND = "Craftbound"
BINDING_NAME_CRAFTBOUND_CRAFT = "Craft the next step"
BINDING_NAME_CRAFTBOUND_BUY = "Auction house: buy next / confirm"
function Craftbound_CraftNext() ns.CraftNext() end

-- The panel ---------------------------------------------------------------------------------

local panel

local function stepLabel(s)
	if s.kind == "train" then return (s.how and "Learn " or "Train ") .. s.rank end
	if s.kind == "disenchant" then return ("%d-%d Disenchant"):format(s.from, s.to) end
	if s.kind == "tool" then return "Tool: " .. s.recipe end
	return ("%d-%d %s"):format(s.from, s.to, s.recipe:gsub("^Enchant ", ""))
end

local function makeRouteRow(parent)
	local b = CreateFrame("Button", nil, parent)
	b:SetSize(284, 15)
	b.mark = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	b.mark:SetPoint("LEFT", 2, 0)
	b.mark:SetWidth(14)
	b.text = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	b.text:SetPoint("LEFT", 18, 0)
	b.text:SetWidth(220)
	b.text:SetJustifyH("LEFT")
	b.text:SetWordWrap(false)
	b.count = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	b.count:SetPoint("RIGHT", -2, 0)
	b:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
	b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	b:SetScript("OnClick", function(self, button)
		if self.summary then
			-- the window on this route's guide, where its stop is set
			local g = ns.ActiveGuide()
			if g and ns.Window and ns.Window.Show then ns.Window.Show(g.key) end
			return
		end
		if button == "RightButton" then
			ns.OpenSwapPicker(self.index)
		elseif IsShiftKeyDown() then
			local st = ns.Status()
			ns.Tick(self.index, not (st and st.done[self.index]))
		elseif self.step and self.step.recipe then
			ns.SelectRecipe(self.step.recipe)
		end
	end)
	UI.Tooltip(b, function(tip, self)
		local s = self.step
		if self.summary then
			tip:AddLine("After your stop", 1, 1, 1)
			tip:AddLine("You chose to stop this route earlier. Change or clear the stop in the Craftbound window (click).", nil, nil, nil, true)
			return
		end
		tip:AddLine(stepLabel(s), 1, 1, 1)
		if s.note then tip:AddLine(s.note, nil, nil, nil, true) end
		for _, m in ipairs((s.recipe and ns.LiveMats(s.recipe)) or s.mats or {}) do
			tip:AddDoubleLine(m.name, "x" .. m.qty .. " per craft", 0.9, 0.9, 0.9, 0.7, 0.7, 0.7)
		end
		if s.alts then tip:AddLine("Alternatives: " .. table.concat(s.alts, ", "), 0.7, 0.7, 0.7, true) end
		if s.source and s.source.cost then tip:AddLine("Recipe: " .. ns.Money(s.source.cost), 0.7, 0.7, 0.7) end
		if s.swappedFrom then tip:AddLine("Your pick, instead of " .. s.swappedFrom .. ".", 1, 0.82, 0, true) end
		tip:AddLine("Click: show the recipe. Shift-click: tick off / undo."
			.. (s.kind == "craft" and " Right-click: craft another recipe instead." or ""), 0.5, 0.8, 1, true)
	end)
	return b
end

local function makeMatRow(parent)
	local r = CreateFrame("Frame", nil, parent)
	r:SetSize(284, 16)
	r.icon = r:CreateTexture(nil, "ARTWORK")
	r.icon:SetSize(14, 14)
	r.icon:SetPoint("LEFT", 4, 0)
	r.text = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	r.text:SetPoint("LEFT", 22, 0)
	r.count = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	r.count:SetPoint("RIGHT", -4, 0)
	return r
end

-- How far the window's own side tabs (other professions) stick out on the right, so the panel
-- docks beside them instead of under them.
local function tabsWidth(self)
	local right = ProfessionsFrame:GetRight()
	if type(right) ~= "number" then return 0 end
	local out = 0
	for _, child in ipairs({ ProfessionsFrame:GetChildren() }) do
		if child ~= self and child:IsShown() then
			local l, r = child:GetLeft(), child:GetRight()
			local w = type(l) == "number" and type(r) == "number" and r - l or 999
			-- a tab: narrow, starts inside or at the edge, sticks out past it
			if w < 64 and r > right and l < right + 8 then out = math.max(out, r - right) end
		end
	end
	return math.min(out, 64)
end

local function dock(f)
	local x = 2 + tabsWidth(f)
	f:ClearAllPoints()
	f:SetPoint("TOPLEFT", ProfessionsFrame, "TOPRIGHT", x, 0)
	f:SetPoint("BOTTOMLEFT", ProfessionsFrame, "BOTTOMRIGHT", x, 0)
end

local function build()
	local f = UI.Panel("CraftboundProfessionPanel", ProfessionsFrame, 300, 400)
	dock(f)

	f.title = UI.Text(f, "big", UI.GOLD)
	f.title:SetPoint("TOPLEFT", 10, -8)
	f.title:SetText("Craftbound")
	f.logo = UI.TitleLogo(f, f.title, 22)
	f.way = UI.WayButton(f)
	f.way:SetPoint("TOPRIGHT", -10, -9)
	f.guide = UI.Text(f, "small", { 0.8, 0.8, 0.8 })
	f.guide:SetPoint("TOPLEFT", 10, -28)

	-- Overwrite my enchants: a small checkbox on the guide's line (Enchanting only)
	f.guide:SetWidth(200)
	f.guide:SetWordWrap(false)
	f.overwrite = CreateFrame("Button", nil, f)
	f.overwrite:SetSize(80, 16)
	f.overwrite:SetPoint("TOPRIGHT", -8, -26)
	f.overwrite:SetScript("OnClick", function() ns.ToggleOverwrite() end)
	f.overwrite.box = f.overwrite:CreateTexture(nil, "ARTWORK")
	f.overwrite.box:SetTexture("Interface\\Buttons\\UI-CheckBox-Up")
	f.overwrite.box:SetSize(16, 16)
	f.overwrite.box:SetPoint("LEFT")
	f.overwrite.check = f.overwrite:CreateTexture(nil, "OVERLAY")
	f.overwrite.check:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
	f.overwrite.check:SetAllPoints(f.overwrite.box)
	f.overwrite.check:Hide()
	local hl = f.overwrite:CreateTexture(nil, "HIGHLIGHT")
	hl:SetTexture("Interface\\Buttons\\UI-CheckBox-Highlight")
	hl:SetBlendMode("ADD")
	hl:SetAllPoints(f.overwrite.box)
	f.overwrite.label = UI.Text(f.overwrite, "small", { 0.8, 0.8, 0.8 })
	f.overwrite.label:SetPoint("LEFT", f.overwrite.box, "RIGHT", 2, 0)
	f.overwrite.label:SetText("Overwrite")
	UI.Tooltip(f.overwrite, function(tip)
		tip:AddLine("Overwrite my enchants")
		tip:AddLine("On: enchants without an item in the sidebar go on your equipped gear and replace whatever "
			.. "enchant is on it today, without asking. Off: the game asks first.", 1, 0.5, 0.4, true)
	end)

	f.bar = UI.Bar(f, 280, 14)
	f.bar:SetPoint("TOPLEFT", 10, -46)

	f.train = UI.Text(f, nil, { 1, 0.4, 0.3 })
	f.train:SetPoint("TOPLEFT", f.bar, "BOTTOMLEFT", 0, -6)
	f.train:SetWidth(280)

	f.now = UI.Text(f, nil, { 1, 1, 1 })
	f.now:SetPoint("TOPLEFT", f.train, "BOTTOMLEFT", 0, -6)
	f.now:SetWidth(280)
	f.sub = UI.Text(f, "small", { 0.75, 0.75, 0.75 })
	f.sub:SetPoint("TOPLEFT", f.now, "BOTTOMLEFT", 0, -3)
	f.sub:SetWidth(280)

	f.mats = UI.Pool(f, makeMatRow)

	f.craft = UI.Button(f, "Craft", 140, 26, function() ns.CraftNext() end)
	f.select = UI.Button(f, "Show recipe", 90, 26, function()
		local st = ns.Status()
		if st and st.step and st.step.recipe then ns.SelectRecipe(st.step.recipe) end
	end)
	f.tick = UI.Button(f, "Done", 50, 26, function()
		local st = ns.Status()
		if st and st.current then ns.Tick(st.current, true) end
	end)
	UI.Tooltip(f.tick, function(tip)
		tip:AddLine("Tick off this step by hand")
		tip:AddLine("For steps Craftbound can't see finish (disenchanting, a rank you trained elsewhere). Shift-click a route line to undo.", nil, nil, nil, true)
	end)
	UI.Tooltip(f.craft, function(tip)
		local plan = ns.CraftPlan()
		tip:AddLine(plan.label)
		if plan.reason then tip:AddLine(plan.reason, 1, 0.5, 0.4, true) end
		local where = ns.CraftTarget()
		if where then tip:AddLine(where, 1, 1, 1, true) end
		tip:AddLine("Bind a key: Key Bindings > AddOns > Craftbound > Craft the next step.", 0.5, 0.8, 1, true)
	end)

	f.altsText = UI.Text(f, "small", { 0.7, 0.7, 0.7 })
	f.altsText:SetWidth(280)

	f.routeTitle = UI.Text(f, nil, UI.GOLD)
	f.routeTitle:SetText("Route")
	f.route = UI.Pool(f, makeRouteRow)

	f:EnableMouseWheel(true)
	f:SetScript("OnMouseWheel", function(self, delta)
		self.routeOffset = (self.routeOffset or 0) - delta * 2
		ns.Refresh()
	end)
	f.footer = UI.Text(f, "small", { 0.8, 0.8, 0.8 })
	f.footer:SetPoint("BOTTOMLEFT", 10, 8)
	f.footer:SetWidth(280)
	return f
end

local function colorOf(s, ctx)
	local live = s.recipe and ns.OpenRecipe(s.recipe)
	if live and live.relativeDifficulty then return UI.DIFFICULTY[live.relativeDifficulty] end
	return P.Color(s, ctx.skill)
end

local function render()
	if not panel or not panel:IsShown() then return end
	local f = panel
	local st, ctx, guide = ns.Status()
	if not guide or not ns.open or guide.profession ~= ns.open.profession then
		f.guide:SetText(ns.open and ("No Craftbound guide for " .. ns.open.profession .. " yet.") or "")
		f.bar:SetValue(0)
		f.bar.text:SetText("")
		f.train:SetText("")
		f.now:SetText("Guides: " .. (function()
			local t = {}
			for _, g in ipairs(ns.Guides) do t[#t + 1] = g.profession end
			return table.concat(t, ", ")
		end)())
		f.sub:SetText("")
		f.mats:Reset() f.mats:Finish()
		f.route:Reset() f.route:Finish()
		f.craft:Hide() f.select:Hide() f.tick:Hide() f.overwrite:Hide()
		ns.RenderEnchantTargets(f, nil)
		f.altsText:SetText("") f.routeTitle:Hide() f.footer:SetText("")
		return
	end
	f.craft:Show() f.select:Show() f.tick:Show() f.routeTitle:Show()
	local enchanting = guide.profession == "Enchanting"
	f.overwrite:SetShown(enchanting)
	local on = ns.db.settings.overwriteEnchants == true
	f.overwrite.check:SetShown(on)
	f.overwrite.label:SetTextColor(unpack(on and { 1, 0.4, 0.3 } or { 0.8, 0.8, 0.8 }))
	ns.RenderEnchantTargets(f, guide, st.step)
	f.guide:SetText(("%s · %s  (%d-%d)"):format(guide.profession, guide.name, guide.from, guide.to))
	f.bar:SetValue(st.percent)
	f.bar.text:SetText(("%d / %d   ·   ~%d crafts to go"):format(ctx.skill, st.stop, st.total))

	if st.train and st.step ~= st.train then
		if st.train.how then
			f.train:SetText(("%s You can now; needed before %d."):format(st.train.how, st.train.before))
		else
			f.train:SetText(("Train %s soon (you can now; needed before %d)."):format(st.train.rank, st.train.before))
		end
	else
		f.train:SetText("")
	end

	local s = st.step
	if st.finished or not s then
		f.now:SetText(UI.Color("green", "Route finished. Well done!"))
		f.sub:SetText("")
	else
		local col = colorOf(s, ctx)
		local text = P.Describe(s, st.left)
		f.now:SetText(col and UI.Color(col, text) or text)
		local bits = {}
		for _, tool in ipairs(s.tools or {}) do
			local owned = ns.HasTool(guide, tool, ctx)
			bits[#bits + 1] = (owned and "Tool: " or UI.Color({ 1, 0.4, 0.3 }, "Needs: ")) .. tool
		end
		if s.station then bits[#bits + 1] = "Craft at: " .. s.station end
		for _, m in ipairs((s.recipe and ns.LiveMats(s.recipe)) or s.mats or {}) do
			local room = st.left
			if ctx.maxSkill then room = math.max(0, math.min(room, ctx.maxSkill - ctx.skill)) end
			local short = P.PartShort(guide, m, (m.qty or 1) * room, ctx, ns.BagCount)
			if short then
				local pr = ns.OpenRecipe(short.part.recipe)
				if ns.open and (not pr or pr.learned == false) then
					bits[#bits + 1] = UI.Color({ 1, 0.4, 0.3 }, partLearnHint(short))
				else
					bits[#bits + 1] = UI.Color(UI.GOLD, ("Make %d %s first (%d crafts): Craft does it."):format(
						short.short, short.name, short.crafts))
				end
			end
		end
		if guide.note and ctx.skill < guide.from then bits[#bits + 1] = UI.Color({ 1, 0.4, 0.3 }, guide.note) end
		if s.note then bits[#bits + 1] = s.note end
		local live = s.recipe and ns.OpenRecipe(s.recipe)
		if live and live.learned == false then
			bits[#bits + 1] = UI.Color({ 1, 0.4, 0.3 }, "Not learned yet. " .. ns.LearnHint(s))
		end
		f.sub:SetText(table.concat(bits, "\n"))
	end

	-- reagents of the current step: have / need
	f.mats:Reset()
	local y = -4
	local anchor = f.sub
	if s and (s.kind == "craft" or s.kind == "tool") then
		for _, m in ipairs(ns.LiveMats(s.recipe) or s.mats or {}) do
			local row = f.mats:Get()
			local need = (m.qty or 1) * st.left
			local have = ctx.have(m)
			row.icon:SetTexture(ns.ItemIcon(m))
			-- counted, but not in the bags: say where they are
			local bags = ns.BagCount(m)
			local away = bags < need and have > bags and (have - bags) or 0
			local bank = away > 0 and math.min(away, ns.BankCount(m)) or 0
			local where = bank > 0 and ("  %d in bank"):format(bank) or (away > 0 and ("  %d in mail"):format(away) or "")
			row.text:SetText(m.name .. (where ~= "" and UI.Color(UI.GOLD, where) or ""))
			row.count:SetText(UI.Color(have >= need and "green" or { 1, 0.4, 0.3 }, ("%d / %d"):format(have, need)))
			row:ClearAllPoints()
			row:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", anchor == f.sub and -4 or 0, y)
			anchor, y = row, 0
		end
	end
	f.mats:Finish()

	local plan = ns.CraftPlan()
	f.craft:SetText(plan.label)
	f.craft:SetEnabled(plan.enabled)
	f.craft:ClearAllPoints()
	f.craft:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", anchor == f.sub and 0 or -4, -8)
	f.select:ClearAllPoints()
	f.select:SetPoint("LEFT", f.craft, "RIGHT", 4, 0)
	f.select:SetEnabled(s and s.recipe and ns.OpenRecipe(s.recipe) ~= nil or false)
	f.tick:ClearAllPoints()
	f.tick:SetPoint("LEFT", f.select, "RIGHT", 4, 0)
	f.tick:SetEnabled(st.current ~= nil)

	f.altsText:ClearAllPoints()
	f.altsText:SetPoint("TOPLEFT", f.craft, "BOTTOMLEFT", 0, -6)
	if not plan.enabled and plan.reason then
		local t = UI.Color({ 1, 0.55, 0.4 }, plan.reason)
		if s and s.alts then
			local alts = {}
			for _, a in ipairs(s.alts) do
				local r = ns.OpenRecipe(a)
				local col = r and r.learned and UI.DIFFICULTY[r.relativeDifficulty]
				alts[#alts + 1] = col and UI.Color(col, a) or a
			end
			t = t .. "\nOr craft: " .. table.concat(alts, ", ")
		end
		f.altsText:SetText(t)
	else
		f.altsText:SetText("")
	end

	f.routeTitle:ClearAllPoints()
	f.routeTitle:SetPoint("TOPLEFT", f.altsText, "BOTTOMLEFT", 0, -10)
	f.route:Reset()
	-- the rows that fit between the title and the footer, around the current step
	local fit = 10
	local top, bottom = f.routeTitle:GetBottom(), f.footer:GetTop()
	if type(top) == "number" and type(bottom) == "number" then fit = math.max(3, math.floor((top - bottom - 6) / 15)) end
	-- the steps on this route; those after the stop target are one line at the end, not a list
	local list, after = {}, 0
	local currentAt
	for i = 1, #guide.steps do
		if st.out[i] then
			after = after + 1
		else
			list[#list + 1] = i
			if i == st.current then currentAt = #list end
		end
	end
	if after > 0 then fit = math.max(2, fit - 1) end
	local n = #list
	local first = math.max(1, (currentAt or n) - 2) + (f.routeOffset or 0)
	first = math.max(1, math.min(first, n - fit + 1))
	f.routeOffset = first - math.max(1, (currentAt or n) - 2)
	local last = math.min(n, first + fit - 1)
	f.routeTitle:SetText(last - first + 1 < n and ("Route  |cff999999(%d-%d of %d, mouse wheel)|r"):format(first, last, n) or "Route")
	local prev = f.routeTitle
	local function place(row)
		row:ClearAllPoints()
		row:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", prev == f.routeTitle and -8 or 0, prev == f.routeTitle and -2 or 0)
		prev = row
	end
	for k = first, last do
		local i = list[k]
		local step = guide.steps[i]
		local row = f.route:Get()
		row.index, row.step, row.summary = i, step, nil
		local cur = i == st.current
		local done = st.done[i]
		row.mark:SetText(done and "|TInterface\\RaidFrame\\ReadyCheck-Ready:12|t" or cur and UI.Color(UI.GOLD, ">") or "")
		local label = stepLabel(step)
		if done then
			row.text:SetText(UI.Color("gray", label))
			row.count:SetText("")
		else
			local col = colorOf(step, ctx)
			if col == "red" then col = { 0.6, 0.6, 0.6 } end -- not learnable yet: plain, not alarming
			row.text:SetText(cur and UI.Color({ 1, 1, 1 }, label) or (col and UI.Color(col, label) or label))
			local left = P.CraftsLeft(step, ctx.skill, ctx.target)
			row.count:SetText(left > 0 and ("x" .. left) or "")
		end
		place(row)
	end
	if after > 0 then
		local row = f.route:Get()
		row.index, row.step, row.summary = nil, nil, true
		row.mark:SetText("")
		row.text:SetText(UI.Color({ 0.55, 0.55, 0.55 }, ("After your stop at %d: %d more steps"):format(st.stop, after)))
		row.count:SetText("")
		place(row)
	end
	f.route:Finish()

	local _, missing = P.Shopping(guide, ctx)
	local cost = P.RecipeCost(guide, ctx)
	local have = missing == 0 and "You have every reagent for the route to your stop."
		or ("Still to get: %d reagents. Open the auction house to buy them."):format(missing)
	f.footer:SetText(have .. (cost > 0 and ("\nRecipes ahead: " .. ns.Money(cost)) or ""))
end

ns.On("CB_REFRESH", render)

local function onShow()
	if not ProfessionsFrame then return end
	if not panel then
		panel = build()
		ns.professionPanel = panel
	end
	ns.ScanOpen()
	dock(panel)
	C_Timer.After(0, function() if panel then dock(panel) end end) -- tabs may be laid out a frame later
	panel:SetShown(ns.db.settings.profPanel)
	if ns.db.settings.autoSelect then
		local st = ns.Status()
		if st and st.step and st.step.recipe then
			C_Timer.After(0.2, function() ns.SelectRecipe(st.step.recipe) end)
		end
	end
	render()
end

ns.On("TRADE_SKILL_SHOW", onShow)
ns.On("TRADE_SKILL_LIST_UPDATE", function() if ns.open or (ProfessionsFrame and ProfessionsFrame:IsShown()) then ns.ScanOpen() end end)
ns.On("TRADE_SKILL_DATA_SOURCE_CHANGED", function() ns.ScanOpen() end)
ns.On("NEW_RECIPE_LEARNED", function() ns.ScanOpen() end)
ns.On("TRADE_SKILL_CLOSE", function()
	ns.open = nil
	replacePending = nil
	ns.Refresh()
end)
ns.On("SKILL_LINES_CHANGED", function() ns.ReadProfessions() end)
ns.On("CHAT_MSG_SKILL", function() ns.ReadProfessions() end)
