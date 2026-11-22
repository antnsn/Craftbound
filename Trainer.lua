-- Trainer: at a profession trainer, a panel beside the trainer window lists what the route needs
-- from it (the next rank, the recipes of the steps still ahead up to your stop, and the recipes of
-- parts those steps need) and one button trains only those. Recipes you know, steps you are past,
-- tools you already have and anything after your stop are left alone.
-- The trainer's list: GetTrainerServiceInfo(i) -> name, subText (a rank), type ("available",
-- "unavailable", "used", "header"). Buying is BuyTrainerService(i), from the button's click.
local _, ns = ...

local UI = ns.UI
local P = ns.Planner

local panel
local isOpen = false

-- What a guide still needs from a trainer, in route order:
-- { name, rank (for a rank), kind = "rank" | "recipe" | "part", from }
function ns.TrainerWants(guide, ctx)
	local list, seen = {}, {}
	local function add(e)
		local k = e.name .. "|" .. (e.rank or "")
		if not seen[k] then
			seen[k] = true
			list[#list + 1] = e
		end
	end
	for i, s in ipairs(guide.steps) do
		if P.InScope(guide, i, ctx.target) and not P.IsDone(guide, i, ctx) then
			if s.kind == "train" then
				add({ name = guide.profession, rank = s.rank, kind = "rank", from = s.reqSkill, level = s.reqLevel })
			elseif (s.kind == "craft" or s.kind == "tool") and not s.buy then
				if s.source and s.source.kind == "trainer" then
					add({ name = s.recipe, kind = "recipe", from = s.from or (s.colors and s.colors[1]) })
				end
				local n = P.CraftsLeft(s, ctx.skill or 0, ctx.target)
				for _, m in ipairs(s.mats or {}) do
					local part = P.Part(guide, m.name)
					-- the part's recipe only when the bags don't already hold enough of the part
					if part and (not part.source or part.source.kind == "trainer")
						and P.PartShort(guide, m, (m.qty or 1) * n, ctx) then
						add({ name = part.recipe, kind = "part", from = s.from })
					end
				end
			end
		end
	end
	return list
end

-- Does trainer service (name, subText) match a wanted entry? A rank is listed as the profession
-- with the rank as its subtext ("Enchanting", "Journeyman") or as one name ("Journeyman Enchanting").
local function matches(e, name, sub, line)
	if e.kind == "rank" then
		if name == e.name and sub == e.rank then return true end
		if not name or name:find(e.rank, 1, true) == nil then return false end
		-- "Journeyman Enchanting" on this profession's skill line, or, when the client doesn't say
		-- the line, a name that starts with the rank and names the profession ("Journeyman
		-- Alchemist" on Forever)
		if line then return line == e.name end
		return name:find("^" .. e.rank .. " ") ~= nil and name:find(e.name:sub(1, 4), 1, true) ~= nil
	end
	return name == e.name
end

local function skillLine(i)
	if not GetTrainerServiceSkillLine then return nil end
	local ok, line = pcall(GetTrainerServiceSkillLine, i)
	return ok and type(line) == "string" and line or nil
end

-- A service's requirements: skill level (and whether it's met, as the client says), player level.
local function requirements(i)
	local skill, met, level
	if GetTrainerServiceSkillReq then
		local ok, _, lvl, has = pcall(GetTrainerServiceSkillReq, i)
		if ok then skill, met = tonumber(lvl), has end
	end
	if GetTrainerServiceLevelReq then
		local ok, lvl = pcall(GetTrainerServiceLevelReq, i)
		if ok then level = tonumber(lvl) end
	end
	return skill, met, level
end

-- Can the character train this service now? The client's type says so for "available", but
-- Forever's trainer window doesn't always mark it: then the requirements decide (skill and level
-- met, not known yet).
local function trainable(s, ctx)
	if s.type == "available" then return true end
	if s.type == "used" or s.type == "header" then return false end
	if s.skill == nil and s.met == nil and s.level == nil then return false end -- nothing to go on
	local skillOk = s.met == true or s.met == 1 or (s.skill ~= nil and (ctx.skill or 0) >= s.skill)
	local levelOk = not s.level or (UnitLevel("player") or 0) >= s.level
	return skillOk and levelOk and not ns.char.known[s.name]
end
ns.TrainerTrainable = trainable

-- The trainer's services: { index, name, sub, type, cost, skill, met, level }
local function services()
	local list = {}
	for i = 1, (GetNumTrainerServices and GetNumTrainerServices() or 0) do
		local name, sub, kind = GetTrainerServiceInfo(i)
		if name and kind ~= "header" then
			local cost = GetTrainerServiceCost and GetTrainerServiceCost(i) or 0
			local skill, met, level = requirements(i)
			list[#list + 1] = { index = i, name = name, sub = sub, type = kind, line = skillLine(i),
				cost = type(cost) == "number" and cost or 0, skill = skill, met = met, level = level }
		end
	end
	return list
end

-- The guide this trainer teaches for (the active one first), its wanted entries matched to the
-- trainer's services, what can be trained now and what it costs.
-- Does the trainer's filter hide known ("used") or later ("unavailable") lines?
local function filterHides()
	if not GetTrainerServiceTypeFilter then return false end
	for _, t in ipairs({ "used", "unavailable" }) do
		local ok, on = pcall(GetTrainerServiceTypeFilter, t)
		if ok and not on then return true end
	end
	return false
end

function ns.TrainerPlan()
	local svc = services()
	local hidden = filterHides()
	local function plan(guide)
		local ctx = ns.Context(guide)
		local rows, now, cost, hits = {}, {}, 0, 0
		for _, e in ipairs(ns.TrainerWants(guide, ctx)) do
			local found
			for _, s in ipairs(svc) do
				if matches(e, s.name, s.sub, s.line) then found = s break end
			end
			local row = { entry = e, service = found }
			if found then
				hits = hits + 1
				row.state = trainable(found, ctx) and "train" or found.type == "used" and "known" or "later"
				if row.state == "train" then
					now[#now + 1] = row
					cost = cost + found.cost
				end
			elseif e.kind ~= "rank" and ns.char.known[e.name] then
				row.state = "known"
			elseif hidden then
				row.state = "hidden" -- the trainer's filter hides known or later lines
			else
				row.state = "elsewhere"
			end
			rows[#rows + 1] = row
		end
		return { guide = guide, rows = rows, now = now, cost = cost, hits = hits }
	end
	local best
	local active = ns.ActiveGuide()
	local tried = {}
	local candidates = {}
	if active then candidates[1] = active end
	for prof in pairs(ns.char.skills) do
		local g = P.ForProfession(prof)[1]
		if g then candidates[#candidates + 1] = g end
	end
	for _, g in ipairs(candidates) do
		if not tried[g.key] then
			tried[g.key] = true
			local p = plan(g)
			if p.hits > 0 and (not best or p.hits > best.hits) then best = p end
		end
	end
	return best
end

local waiting -- a purchase was sent: no second one until the trainer's list has caught up

function ns.TrainRoute()
	if InCombatLockdown() or waiting then return end
	local p = ns.TrainerPlan()
	if not p or #p.now == 0 then return ns.Print("Nothing on your route to train here right now.") end
	if GetMoney() < p.cost then
		return ns.Print(("Training the route's recipes costs %s; you have %s."):format(ns.Money(p.cost), ns.Money(GetMoney())))
	end
	-- from the bottom up, so a bought line moving out of the list can't shift the ones still to buy
	local want = {}
	for _, row in ipairs(p.now) do want[row.service.index] = row end
	local names = {}
	for i = GetNumTrainerServices(), 1, -1 do
		local row = want[i]
		if row then
			local name, sub, kind = GetTrainerServiceInfo(i)
			if kind ~= "used" and matches(row.entry, name, sub, skillLine(i)) then
				BuyTrainerService(i)
				names[#names + 1] = row.entry.rank and (row.entry.rank .. " " .. row.entry.name) or row.entry.name
			end
		end
	end
	ns.Print(("Trained %d: %s."):format(#names, table.concat(names, ", ")))
	if #names > 0 then
		waiting = true
		if panel then panel.train:SetEnabled(false) end
		C_Timer.After(2, function() waiting = nil if panel and panel:IsShown() then ns.Fire("TRAINER_UPDATE") end end)
	end
end

-- /craft trainerinfo: what the client says about each service (for reports from the game)
function ns.TrainerInfo()
	local n = GetNumTrainerServices and GetNumTrainerServices() or 0
	ns.Print(("trainer: %d services, profession trainer: %s"):format(n, tostring(IsTradeskillTrainer and IsTradeskillTrainer())))
	for i = 1, n do
		local name, sub, kind = GetTrainerServiceInfo(i)
		local skill, met, level = requirements(i)
		print(("  %d. %s | %s | %s | skill %s (%s) | level %s | %s"):format(i, tostring(name), tostring(sub),
			tostring(kind), tostring(skill), tostring(met), tostring(level), tostring(skillLine(i))))
	end
end

-- Panel ---------------------------------------------------------------------------------------

local STATE = {
	train = { 0.25, 0.85, 0.25 }, later = { 0.6, 0.6, 0.6 }, known = { 0.4, 0.4, 0.4 }, elsewhere = { 0.8, 0.55, 0.3 },
	hidden = { 0.6, 0.6, 0.6 },
}

local function makeRow(parent)
	local r = UI.Text(parent, "small", { 1, 1, 1 })
	r:SetWidth(264)
	r:SetWordWrap(false)
	return r
end

local function build()
	local host = rawget(_G, "ClassTrainerFrame")
	local f = UI.Panel("CraftboundTrainerPanel", host or UIParent, 280, 300)
	if host then f:SetPoint("TOPLEFT", host, "TOPRIGHT", 4, 0) else f:SetPoint("LEFT", UIParent, "LEFT", 420, 0) end
	f.title = UI.Text(f, nil, UI.GOLD)
	f.title:SetPoint("TOPLEFT", 8, -8)
	f.title:SetWidth(240)
	f.logo = UI.TitleLogo(f, f.title, 18)
	f.guide = UI.Text(f, "small", { 0.75, 0.75, 0.75 })
	f.guide:SetPoint("TOPLEFT", 8, -30)
	f.guide:SetWidth(264)
	f.rows = UI.Pool(f, makeRow)
	f.train = UI.Button(f, "Train", 264, 24, function() ns.TrainRoute() end)
	f.train:SetPoint("BOTTOMLEFT", 8, 8)
	UI.Tooltip(f.train, function(tip)
		tip:AddLine("Craftbound: train the route")
		tip:AddLine("Only what your route needs from here, up to your stop: the next rank, the recipes of the steps ahead and of the parts they need. Recipes you know or are past are left alone.", 1, 1, 1, true)
	end)
	f.status = UI.Text(f, "small", { 0.85, 0.85, 0.85 })
	f.status:SetPoint("BOTTOMLEFT", f.train, "TOPLEFT", 0, 4)
	f.status:SetWidth(264)
	return f
end

local LABEL = { train = "train now", later = "at %d", known = "known", elsewhere = "not taught here",
	hidden = "hidden by the trainer's filter" }

local function render()
	local want = isOpen and ns.db.settings.trainerPanel and IsTradeskillTrainer and IsTradeskillTrainer()
	local p = want and ns.TrainerPlan()
	if not p then
		if panel then panel:Hide() end
		return
	end
	panel = panel or build()
	local host = rawget(_G, "ClassTrainerFrame")
	if host and panel:GetParent() ~= host then
		panel:SetParent(host)
		panel:ClearAllPoints()
		panel:SetPoint("TOPLEFT", host, "TOPRIGHT", 4, 0)
	end
	panel:Show()
	local g = p.guide
	local ctx = ns.Context(g)
	panel.title:SetText("Craftbound · " .. g.profession)
	panel.guide:SetText(("%s, stop at %d. Skill %d."):format(g.name, P.End(g, ctx), ctx.skill))
	panel.rows:Reset()
	local y, shown, max = -48, 0, 14
	for _, row in ipairs(p.rows) do
		if row.state ~= "known" then
			shown = shown + 1
			if shown <= max then
				local t = panel.rows:Get()
				t:ClearAllPoints()
				t:SetPoint("TOPLEFT", 8, y)
				y = y - 14
				local e = row.entry
				local name = e.rank and (e.rank .. " " .. e.name) or e.name
				local state = LABEL[row.state]
				if row.state == "later" then
					state = state:format((row.service and row.service.skill) or e.from or 0) .. (e.level and (UnitLevel("player") or 0) < e.level and (", level " .. e.level) or "")
				end
				local cost = row.state == "train" and row.service.cost > 0 and ("  " .. ns.Money(row.service.cost)) or ""
				t:SetText(UI.Color(STATE[row.state], name .. "  ·  " .. state) .. cost)
			end
		end
	end
	panel.rows:Finish()
	if shown == 0 then
		local t = panel.rows:Get()
		t:ClearAllPoints()
		t:SetPoint("TOPLEFT", 8, y)
		t:SetText(UI.Color("green", "You know everything your route needs from here."))
		y = y - 14
		panel.rows:Finish()
	elseif shown > max then
		y = y - 2
	end
	local n = #p.now
	panel.train:SetText(n > 0 and ("Train %d (%s)"):format(n, ns.Money(p.cost)) or "Nothing to train now")
	panel.train:SetEnabled(n > 0 and GetMoney() >= p.cost and not waiting)
	panel.status:SetText(n > 0 and GetMoney() < p.cost and UI.Color({ 1, 0.4, 0.3 }, "Not enough money for all of it.")
		or (shown > max and ("and %d more on the route"):format(shown - max) or ""))
	panel:SetHeight(math.max(140, -y + 70))
end

ns.On("TRAINER_SHOW", function()
	isOpen = true
	render()
end)
ns.On("TRAINER_UPDATE", function()
	waiting = nil
	render()
end)
ns.On("TRAINER_CLOSED", function()
	isOpen = false
	render()
end)
ns.On("CB_REFRESH", function() if isOpen then render() end end)
