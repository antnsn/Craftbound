-- Craftbound core: saved variables, the event bus, the character state and the slash command.
--
-- CraftboundDB (account):     settings, item IDs found by name, recipes seen in the window
-- CraftboundCharDB (character): active guide, per-guide ticks and history, skills, bank counts
local addonName, ns = ...

ns.name = addonName
ns.title = "|cffe0a040Craft|r|cfff0e0c0bound|r"
ns.MEDIA = "Interface\\AddOns\\Craftbound\\Media\\"
-- Craftbound has one look. LibBound's crop_shots.py reads the addon's own skin from this line and
-- files /craft shots under docs/screenshots.
ns.skin = "craftbound"

local DEFAULTS = {
	settings = {
		tracker = true,      -- show the resume tracker outside the windows
		profPanel = true,    -- dock the panel to the profession window
		ahPanel = true,      -- dock the panel to the auction house
		autoSelect = true,   -- select the step's recipe when the profession window opens
		buffer = 0,          -- extra percent on top of the guide's safe counts when shopping
		minimap = true,      -- the minimap button
		capGuard = true,     -- ask before Blizzard's Create buttons craft at a rank's cap (CapGuard.lua)
		trainerPanel = true, -- the route's recipes beside the profession trainer (Trainer.lua)
	},
	minimapIcon = nil,       -- LibDBIcon's position table { minimapPos, hide }
	items = {},              -- [name] = itemID, learned at runtime
	recipes = {},            -- [recipe name] = { id = recipeID, mats = { {id,name,qty} }, colors = {...} }
	prices = {},             -- [itemID] = { unit = copper, at = time() } from Craftbound's AH scans
	vendorPrices = {},       -- [itemID] = copper, buy prices seen at merchants
	custom = {},             -- custom guides (Custom.lua), a list of guide tables
	customNext = 1,          -- the next custom guide number
}

local CHAR_DEFAULTS = {
	active = nil,            -- guide key, e.g. "Enchanting:Easiest"
	guides = {},             -- [key] = { ticks = {}, history = {}, started, last, target }
	known = {},              -- [recipe name] = true, recipes this character has learned
	skills = {},             -- [profession] = { rank, max, seen }
	mail = {},               -- [itemID] = count bought or waiting in the mailbox
	tracker = nil,           -- { point, x, y }
	window = nil,            -- { point, x, y } of the Craftbound window
	trackerHidden = nil,     -- the player closed it
}

local function fill(t, defaults)
	for k, v in pairs(defaults) do
		if t[k] == nil then
			if type(v) == "table" then t[k] = fill({}, v) else t[k] = v end
		elseif type(v) == "table" and type(t[k]) == "table" then
			fill(t[k], v)
		end
	end
	return t
end

-- Event bus -------------------------------------------------------------------------------

local frame = CreateFrame("Frame")
local handlers = {}

function ns.On(event, fn)
	local list = handlers[event]
	if not list then
		list = {}
		handlers[event] = list
		if not event:find("^CB_") then frame:RegisterEvent(event) end
	end
	list[#list + 1] = fn
end

local function dispatch(event, ...)
	local list = handlers[event]
	if not list then return end
	for i = 1, #list do
		local ok, err = pcall(list[i], ...)
		if not ok then geterrorhandler()(err) end
	end
end
ns.Fire = dispatch

frame:SetScript("OnEvent", function(_, event, ...) dispatch(event, ...) end)

-- Something the panels show changed: refresh them on the next frame, once.
local pending
function ns.Refresh()
	if pending then return end
	pending = true
	C_Timer.After(0, function()
		pending = nil
		dispatch("CB_REFRESH")
	end)
end

function ns.Print(msg)
	print(ns.title .. ": " .. msg)
end

-- Character state ---------------------------------------------------------------------------

function ns.GuideState(key)
	local g = ns.char.guides[key]
	if not g then
		g = { ticks = {}, history = {}, started = time() }
		ns.char.guides[key] = g
	end
	-- an edited custom guide: its step numbers changed, so hand ticks no longer fit
	local guide = ns.Planner.Find(key)
	if guide and guide.rev ~= g.rev then
		g.ticks, g.rev = {}, guide.rev
	end
	return g
end

function ns.ActiveGuide()
	local key = ns.char and ns.char.active
	return key and ns.Planner.Find(key)
end

function ns.SetActive(key)
	local g = ns.Planner.Find(key)
	if not g then return false end
	ns.char.active = key
	ns.char.trackerHidden = nil
	ns.GuideState(key).last = time()
	ns.Refresh()
	return true
end

-- Remember a skill reading; returns true when it changed.
function ns.NoteSkill(profession, rank, maxRank)
	if not profession or not rank then return false end
	local s = ns.char.skills[profession]
	if s and s.rank == rank and s.max == maxRank then return false end
	local old = s and s.rank
	ns.char.skills[profession] = { rank = rank, max = maxRank, seen = time() }
	-- history for the guides of this profession
	for _, g in ipairs(ns.Planner.ForProfession(profession)) do
		local gs = ns.char.guides[g.key]
		if gs and old and rank > old then
			local h = gs.history
			h[#h + 1] = { t = time(), skill = rank }
			while #h > 300 do table.remove(h, 1) end
			gs.last = time()
		end
	end
	ns.Refresh()
	return true
end

-- The planner context for a guide, from what we know about this character.
function ns.Context(guide)
	local s = ns.char.skills[guide.profession] or {}
	local gs = ns.char.guides[guide.key] and ns.GuideState(guide.key) or { ticks = {} }
	return {
		skill = s.rank or 0,
		maxSkill = s.max,
		level = UnitLevel("player") or 0,
		ticks = gs.ticks,
		have = ns.Have,
		liveMats = ns.LiveMats,
		target = gs.target,
		known = function(recipe) return ns.char.known[recipe] or false end,
	}
end

-- The skill to stop at in a guide (nil: the guide's end).
function ns.SetTarget(key, target)
	local g = ns.Planner.Find(key)
	if not g then return end
	ns.GuideState(key).target = (target and target < g.to and target > g.from) and target or nil
	ns.Refresh()
end

-- The stop targets a guide offers: the rank caps inside its range, and its end.
function ns.Targets(guide)
	local t = {}
	for _, cap in ipairs({ 150, 225, 300 }) do
		if cap > guide.from and cap < guide.to then t[#t + 1] = cap end
	end
	t[#t + 1] = guide.to
	return t
end

function ns.Status(guide)
	guide = guide or ns.ActiveGuide()
	if not guide then return nil end
	local ctx = ns.Context(guide)
	return ns.Planner.Status(guide, ctx), ctx, guide
end

-- Real reagents of a recipe, once seen in the profession window.
function ns.LiveMats(recipe)
	local r = ns.db.recipes[recipe]
	return r and r.mats
end

function ns.Tick(index, on)
	local guide = ns.ActiveGuide()
	if not guide then return end
	ns.GuideState(guide.key).ticks[index] = on and true or nil
	ns.Refresh()
end

-- Money text from copper.
function ns.Money(copper)
	copper = math.floor(copper or 0)
	local g, s, c = math.floor(copper / 10000), math.floor(copper / 100) % 100, copper % 100
	if g > 0 then return ("%d|cffffd700g|r %d|cffc7c7cfs|r"):format(g, s) end
	if s > 0 then return ("%d|cffc7c7cfs|r %d|cffeda55fc|r"):format(s, c) end
	return ("%d|cffeda55fc|r"):format(c)
end

-- Login -----------------------------------------------------------------------------------

ns.On("ADDON_LOADED", function(name)
	if name ~= addonName then return end
	CraftboundDB = fill(CraftboundDB or {}, DEFAULTS)
	CraftboundCharDB = fill(CraftboundCharDB or {}, CHAR_DEFAULTS)
	ns.db, ns.char = CraftboundDB, CraftboundCharDB
	if ns.Custom then ns.Custom.Load() end
	-- guides that no longer exist (the old "Easiest" routes): their progress moves to the
	-- profession's guide now (history and stop; ticks were by step number)
	local function successor(key)
		if key:find("^custom:") then return nil end
		local prof = key:match("^(.-):")
		return prof and ns.Planner.ForProfession(prof)[1]
	end
	local gone = {}
	for key in pairs(ns.char.guides) do
		if not ns.Planner.Find(key) then gone[#gone + 1] = key end
	end
	for _, key in ipairs(gone) do
		local now = successor(key)
		if now then
			local old = ns.char.guides[key]
			local cur = ns.char.guides[now.key] or { ticks = {} }
			if not (cur.history and #cur.history > 0) then cur.history = old.history or {} end
			cur.target = cur.target or old.target
			cur.started = cur.started or old.started
			cur.last = cur.last or old.last
			ns.char.guides[now.key] = cur
			ns.char.guides[key] = nil
		end
	end
	local active = ns.char.active
	if active and not ns.Planner.Find(active) then
		local now = successor(active)
		ns.char.active = now and now.key or nil
	end
	dispatch("CB_LOADED")
end)

ns.On("PLAYER_LOGIN", function()
	ns.ReadProfessions()
	-- pick the guide by itself when the character has exactly one profession with a guide
	if not ns.char.active then
		local found
		for prof in pairs(ns.char.skills) do
			local list = ns.Planner.ForProfession(prof)
			if list[1] then
				if found then found = false break end
				found = list[1].key
			end
		end
		if found then ns.char.active = found end
	end
	dispatch("CB_READY")
	ns.Refresh()
	local guide = ns.ActiveGuide()
	if guide then
		local st = ns.Status(guide)
		ns.Print(("%s %s, skill %d. Next: %s"):format(guide.profession, guide.name,
			ns.Context(guide).skill, ns.Planner.Describe(st.step, st.left)))
	end
end)

-- Slash -----------------------------------------------------------------------------------

local HELP = {
	"/craft  open the Craftbound window (guides, where to stop and what it costs, your own guides)",
	"/craft tracker  show or hide the tracker",
	"/craft guide  pick a guide (or /craft guide enchanting, /craft guide alchemy)",
	"/craft stop 150|225|300|end  where to stop in the active guide",
	"/craft list  the shopping list in chat",
	"/craft tick  tick off the current step by hand (/craft untick N to undo step N)",
	"/craft reset  forget this character's progress in the active guide",
	"/craft toggle panel|shop|select|tracker|minimap|cap|trainer  turn a part on or off",
}

local TOGGLES = {
	panel = { "profPanel", "the panel beside the profession window" },
	shop = { "ahPanel", "the shopping panel beside the auction house" },
	select = { "autoSelect", "selecting the step's recipe when the window opens" },
	tracker = { "tracker", "the tracker" },
	minimap = { "minimap", "the minimap button" },
	cap = { "capGuard", "asking before Blizzard's Create buttons craft at a rank's cap" },
	trainer = { "trainerPanel", "the route's recipes beside the profession trainer" },
}

local function findGuide(word)
	word = word:lower()
	for _, g in ipairs(ns.Guides) do
		if g.profession:lower():find(word, 1, true) or g.key:lower() == word then return g end
	end
end

local function slash(msg)
	msg = (msg or ""):gsub("^%s+", ""):gsub("%s+$", "")
	local cmd, rest = msg:match("^(%S*)%s*(.-)$")
	cmd = cmd:lower()
	if cmd == "" or cmd == "window" then
		ns.Window.Toggle()
	elseif cmd == "tracker" then
		ns.ToggleTracker()
	elseif cmd == "stop" then
		local guide = ns.ActiveGuide()
		if not guide then return ns.Print("Pick a guide first: /craft guide.") end
		local t = tonumber(rest)
		local ok = rest:lower() == "end"
		for _, x in ipairs(ns.Targets(guide)) do if x == t then ok = true end end
		if not ok then
			return ns.Print(("Stops for %s %s: %s, or end."):format(guide.profession, guide.name,
				table.concat(ns.Targets(guide), ", ")))
		end
		ns.SetTarget(guide.key, t)
		local st = ns.Status(guide)
		ns.Print(("%s %s: stopping at %d."):format(guide.profession, guide.name, st.stop))
	elseif cmd == "shots" then
		ns.Shots() -- screenshots for the docs (Shots.lua); not in the help
	elseif cmd == "help" then
		for _, line in ipairs(HELP) do print(line) end
	elseif cmd == "guide" or cmd == "guides" then
		if rest ~= "" then
			local g = findGuide(rest)
			if g and ns.SetActive(g.key) then
				ns.Print(("Active guide: %s %s."):format(g.profession, g.name))
				ns.ShowTracker()
			else
				ns.Print("No guide matches '" .. rest .. "'.")
			end
		else
			ns.ShowGuidePicker()
		end
	elseif cmd == "list" or cmd == "shop" then
		local guide = ns.ActiveGuide()
		if not guide then return ns.Print("Pick a guide first: /craft guide.") end
		local list, missing = ns.Planner.Shopping(guide, ns.Context(guide))
		if missing == 0 then return ns.Print("You have everything for the rest of the route.") end
		ns.Print(("Still to get for %s:"):format(guide.profession))
		for _, e in ipairs(list) do
			if e.missing > 0 then print(("  %s x%d (have %d)"):format(e.name, e.missing, e.have)) end
		end
	elseif cmd == "tick" or cmd == "untick" then
		local st = ns.Status()
		if not st then return ns.Print("Pick a guide first: /craft guide.") end
		local n = tonumber(rest) or st.current
		if n then
			ns.Tick(n, cmd == "tick")
			ns.Print(("Step %d %s."):format(n, cmd == "tick" and "ticked off" or "back on the list"))
		end
	elseif cmd == "toggle" then
		local t = TOGGLES[rest:lower()]
		if not t then return ns.Print("/craft toggle panel, shop, select, tracker, minimap, cap or trainer.") end
		local set = ns.db.settings
		set[t[1]] = not set[t[1]]
		ns.Print(("%s: %s."):format(t[2], set[t[1]] and "on" or "off"))
		if ns.professionPanel then ns.professionPanel:SetShown(set.profPanel and ns.open ~= nil) end
		ns.AH.UpdatePanel()
		if ns.UpdateMinimap then ns.UpdateMinimap() end
		if ns.UpdateCapGuard then ns.UpdateCapGuard() end
		ns.Refresh()
	elseif cmd == "reset" then
		local guide = ns.ActiveGuide()
		if guide then
			ns.char.guides[guide.key] = nil
			ns.Refresh()
			ns.Print("Progress in " .. guide.profession .. " " .. guide.name .. " forgotten.")
		end
	else
		for _, line in ipairs(HELP) do print(line) end
	end
end

SLASH_CRAFTBOUND1 = "/craftbound"
SLASH_CRAFTBOUND2 = "/craft"
SlashCmdList.CRAFTBOUND = slash
ns.Slash = slash
