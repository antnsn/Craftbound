-- Custom guides: copies, new guides built from the open profession window, imports. They live in
-- CraftboundDB.custom (account-wide) and join ns.Guides at load, keyed "custom:<n>", so every
-- panel uses them like the built-in ones.
local _, ns = ...

local Custom = {}
ns.Custom = Custom

local function deepcopy(v)
	if type(v) ~= "table" then return v end
	local t = {}
	for k, x in pairs(v) do t[k] = deepcopy(x) end
	return t
end
Custom.Copy = deepcopy

local function indexIn(list, key)
	for i, g in ipairs(list) do
		if g.key == key or (g.id and ("custom:" .. g.id) == key) then return i end
	end
end

local function register(g)
	g.key = "custom:" .. g.id
	g.custom = true
	local i = indexIn(ns.Guides, g.key)
	if i then ns.Guides[i] = g else ns.Guides[#ns.Guides + 1] = g end
	if ns.RegisterGuideItems then ns.RegisterGuideItems(g) end
end

-- Join the saved custom guides to ns.Guides (at load, before the active guide is checked).
function Custom.Load()
	-- an entry this version can't read stays saved (a later version may), it just isn't listed
	for _, saved in ipairs(ns.db.custom) do
		local g = ns.Share.Sanitize(saved)
		if g and type(saved.id) == "number" then
			g.id, g.rev = saved.id, saved.rev
			register(g)
		end
	end
end

local function author()
	local name = UnitName and UnitName("player")
	return type(name) == "string" and name or nil
end

-- Store a guide (already sanitised, or a draft to sanitise) as a new custom guide.
function Custom.Add(guide)
	local g, err = ns.Share.Sanitize(guide)
	if not g then return nil, err end
	g.id = ns.db.customNext
	ns.db.customNext = ns.db.customNext + 1
	ns.db.custom[#ns.db.custom + 1] = g
	register(g)
	ns.Refresh()
	return g
end

-- A custom copy of any guide, to edit.
function Custom.CopyOf(guide)
	local t = deepcopy(guide)
	t.key, t.custom, t.id = nil, nil, nil
	t.name = (guide.name .. " (copy)"):sub(1, 60)
	t.author = author()
	return Custom.Add(t)
end

-- Replace a custom guide with an edited draft. Returns the saved guide or nil, reason.
function Custom.Save(key, draft)
	local i = indexIn(ns.db.custom, key)
	if not i then return nil, "not a custom guide" end
	local g, err = ns.Share.Sanitize(draft)
	if not g then return nil, err end
	-- the range follows the steps after an edit
	local lo, hi = 450, 0
	for _, s in ipairs(g.steps) do
		if s.from and s.from < lo then lo = s.from end
		if s.to and s.to > hi then hi = s.to end
	end
	if hi > 0 then g.from, g.to = (lo < 450 and lo or g.from), hi end
	g.id = ns.db.custom[i].id
	-- steps changed: hand ticks (kept by step number) no longer fit; GuideState clears them
	g.rev = (ns.db.custom[i].rev or 0) + 1
	ns.db.custom[i] = g
	register(g)
	ns.Refresh()
	return g
end

function Custom.Delete(key)
	local i = indexIn(ns.db.custom, key)
	if not i then return false end
	table.remove(ns.db.custom, i)
	local j = indexIn(ns.Guides, key)
	if j then table.remove(ns.Guides, j) end
	if ns.char.active == key then ns.char.active = nil end
	ns.Refresh()
	return true
end

-- A draft for a new guide of a profession (not saved until it has steps).
function Custom.Draft(profession)
	return { profession = profession, name = ("My %s guide"):format(profession), author = author(), steps = {} }
end

-- A craft step for a recipe from the open window: reagents from its schematic, crafts estimated
-- (the client does not tell skill-up thresholds: the author can change the count).
function Custom.StepFor(recipeInfo, from, to)
	local mats = ns.ReadMats and ns.ReadMats(recipeInfo.recipeID) or nil
	local n = math.max(1, to - from)
	return { kind = "craft", recipe = recipeInfo.name, from = from, to = to,
		expected = n, safe = math.ceil(n * 1.3), mats = mats or {}, source = { kind = "trainer" } }
end
