-- Screenshots for the docs and the CurseForge page: "/craft shots" (not in the help) shows each
-- Craftbound frame in turn and takes a screenshot. Where each frame sat goes into
-- CraftboundDB.shots (the same shape as LibBound's Shots.lua), so after a /reload
--   python3 LibBound/tools/crop_shots.py Craftbound
-- cuts the frames out into docs/screenshots/. The active guide's profession window is opened for
-- its shot (and closed again); the auction house and trainer panels are shot when those are open. Nothing is saved or bought:
-- the editor shows an unsaved draft and is cancelled afterwards.
local _, ns = ...

local SHOT_WAIT = 0.7 -- seconds for a frame to draw before the shot
local SHOT_GAP = 1.6  -- between shots: screenshot file names only have whole seconds

local function IsSecret(v)
	local f = rawget(_G, "issecretvalue")
	return f and f(v) or false
end

-- a frame's place on screen, top-left origin, as fractions of UIParent (independent of UI scale),
-- with what its own textures and child frames draw outside it, two levels deep
local function Rect(f, depth)
	if not (f and f.IsVisible and f:IsVisible()) then return nil end
	local L, B, R, T
	local function Add(o)
		if not (o.IsVisible and o:IsVisible()) then return end
		local ok, l, b, w, h = pcall(o.GetRect, o)
		if not ok or IsSecret(l) or IsSecret(b) or IsSecret(w) or IsSecret(h) then return end
		if not l or not w or w <= 0 or h <= 0 then return end
		local es = o.GetEffectiveScale and o:GetEffectiveScale()
		if not es or IsSecret(es) then return end
		local s = es / UIParent:GetEffectiveScale()
		l, b, w, h = l * s, b * s, w * s, h * s
		L, B = math.min(L or l, l), math.min(B or b, b)
		R, T = math.max(R or l + w, l + w), math.max(T or b + h, b + h)
	end
	local function Walk(o, d)
		Add(o)
		if o.GetRegions then for _, r in ipairs({ o:GetRegions() }) do Add(r) end end
		local clips = (o.IsObjectType and o:IsObjectType("ScrollFrame")) or (o.DoesClipChildren and o:DoesClipChildren())
		if d > 0 and not clips and o.GetChildren then
			for _, c in ipairs({ o:GetChildren() }) do Walk(c, d - 1) end
		end
	end
	Walk(f, depth or 2)
	if not L then return nil end
	local W, H = UIParent:GetWidth(), UIParent:GetHeight()
	L, B, R, T = math.max(0, L), math.max(0, B), math.min(W, R), math.min(H, T)
	if R <= L or T <= B then return nil end
	return { x = L / W, y = 1 - T / H, w = (R - L) / W, h = (T - B) / H }
end

-- two rects as one (a panel docked beside Blizzard's window)
local function Union(a, b)
	if not a then return b end
	if not b then return a end
	local x, y = math.min(a.x, b.x), math.min(a.y, b.y)
	return { x = x, y = y, w = math.max(a.x + a.w, b.x + b.w) - x, h = math.max(a.y + a.h, b.y + b.h) - y }
end

-- chat windows: other players' names and messages, for the crop script to pixelate
local function ChatRects()
	local list = {}
	for i = 1, (rawget(_G, "NUM_CHAT_WINDOWS") or 10) do
		for _, name in ipairs({ "ChatFrame" .. i, "ChatFrame" .. i .. "EditBox" }) do
			local r = Rect(rawget(_G, name), 0)
			if r then list[#list + 1] = r end
		end
	end
	return list
end

local function named(name) return rawget(_G, name) end

-- the steps: { name, prepare(), rects() -> { main = rect } }
local function Steps()
	local W = ns.Window
	local guide = ns.ActiveGuide() or ns.Guides[1]
	local steps = {}
	local function win() return named("CraftboundWindow") end
	local function hideAll()
		for _, n in ipairs({ "CraftboundWindow", "CraftboundShare" }) do
			local f = named(n)
			if f and f:IsShown() then f:Hide() end
		end
	end
	steps[#steps + 1] = { name = "window",
		prepare = function() hideAll() W.Show(guide.key) end,
		rects = function() return { main = Rect(win()) } end }
	steps[#steps + 1] = { name = "window-editor",
		prepare = function()
			W.Show(guide.key)
			W.Preview(guide)
		end,
		rects = function() return { main = Rect(win()) } end }
	steps[#steps + 1] = { name = "export",
		prepare = function()
			W.CancelEdit()
			W.ShowShare(ns.Share.Export(guide))
		end,
		rects = function() return { main = Rect(named("CraftboundShare")) } end }
	steps[#steps + 1] = { name = "tracker", optional = true, -- shown only with an active guide
		prepare = function()
			hideAll()
			if ns.tracker and not ns.tracker:IsShown() and ns.ShowTracker then ns.ShowTracker() end
			-- above the profession or auction panels it may sit behind (its strata is LOW)
			if ns.tracker then ns.tracker:SetFrameStrata("DIALOG") end
		end,
		rects = function() return { main = Rect(ns.tracker) } end }
	local trainer = named("CraftboundTrainerPanel")
	if trainer and trainer:IsShown() then
		steps[#steps + 1] = { name = "trainer", optional = true, prepare = function() hideAll() end,
			rects = function()
				local host = named("ClassTrainerFrame")
				return { main = Union(host and Rect(host, 0), Rect(trainer)), panel = Rect(trainer) }
			end }
	end
	if ns.auctionPanel and ns.auctionPanel:IsShown() then
		steps[#steps + 1] = { name = "auction-house", prepare = function() end,
			rects = function()
				return { main = Union(Rect(named("AuctionHouseFrame"), 0), Rect(ns.auctionPanel)), shop = Rect(ns.auctionPanel) }
			end }
	end
	-- last: the profession window it may open itself would cover the trainer and auction house
	-- the profession window: opened for the guide's profession when it isn't open yet
	local line
	for id, name in pairs(ns.SKILL_LINES or {}) do
		if name == guide.profession then line = id end
	end
	local T = C_TradeSkillUI
	local canOpen = line and ns.char.skills[guide.profession] and T and T.OpenTradeSkill
	if (ns.professionPanel and ns.professionPanel:IsShown()) or canOpen then
		steps[#steps + 1] = { name = "profession-window", wait = 2, optional = true,
			prepare = function()
				hideAll()
				if not (ns.professionPanel and ns.professionPanel:IsShown()) and canOpen then
					ns.openedForShots = true
					T.OpenTradeSkill(line)
				end
			end,
			rects = function()
				return { main = Union(Rect(named("ProfessionsFrame"), 0), Rect(ns.professionPanel)), panel = Rect(ns.professionPanel) }
			end }
	end
	return steps
end

function ns.Shots()
	if ns.shooting then return ns.Print("screenshots are already running.") end
	if InCombatLockdown() then return ns.Print("leave combat first.") end
	local steps = Steps()
	local trackerHidden = ns.char.trackerHidden
	local run = { skin = ns.skin, at = date("%Y-%m-%d %H:%M"), list = {} }
	local cvar = rawget(_G, "C_CVar")
	local format = cvar and cvar.GetCVar and cvar.GetCVar("screenshotFormat")
	if format then cvar.SetCVar("screenshotFormat", "png") end
	ns.shooting = true
	local function Finish(done, why)
		ns.shooting = nil
		if format then cvar.SetCVar("screenshotFormat", format) end
		ns.Window.CancelEdit()
		for _, n in ipairs({ "CraftboundShare", "CraftboundWindow" }) do
			local f = named(n)
			if f and f:IsShown() then f:Hide() end
		end
		ns.char.trackerHidden = trackerHidden
		if ns.tracker then ns.tracker:SetFrameStrata("LOW") end
		if ns.openedForShots then
			ns.openedForShots = nil
			if C_TradeSkillUI.CloseTradeSkill then pcall(C_TradeSkillUI.CloseTradeSkill) end
		end
		ns.Refresh()
		ns.db.shots = ns.db.shots or {}
		ns.db.shots[run.skin] = run
		local missing = {}
		local shot = {}
		for _, s in ipairs(run.list) do shot[s.name] = true end
		if not shot["profession-window"] then missing[#missing + 1] = "a profession window" end
		if not shot["auction-house"] then missing[#missing + 1] = "the auction house" end
		local msg = (done and "" or ("stopped (" .. (why or "combat") .. "): ")) .. #run.list
			.. " screenshots. /reload, then: python3 LibBound/tools/crop_shots.py Craftbound"
		ns.Print(msg)
		if #missing > 0 then
			ns.Print("Open " .. table.concat(missing, " or ") .. " and run /craft shots again to get those panels too.")
		end
		local errors = rawget(_G, "UIErrorsFrame")
		if errors then errors:AddMessage("Craftbound: " .. msg, 1, 0.82, 0) end
		if SOUNDKIT and SOUNDKIT.READY_CHECK then PlaySound(SOUNDKIT.READY_CHECK) end
	end
	local function Next(i)
		local st = steps[i]
		if not st or InCombatLockdown() then Finish(not st) return end
		local ok, err = pcall(st.prepare)
		if not ok then Finish(false, st.name .. ": " .. tostring(err)) return end
		C_Timer.After(st.wait or SHOT_WAIT, function()
			if InCombatLockdown() then Finish(false) return end
			local got, rects = pcall(st.rects)
			if not got then Finish(false, st.name .. ": " .. tostring(rects)) return end
			-- a window that didn't open (the game refused): no shot, go on
			if st.optional and not (rects and rects.main) then Next(i + 1) return end
			run.list[#run.list + 1] = { name = st.name, at = date("%m%d%y_%H%M%S"), rects = rects, hide = ChatRects() }
			Screenshot()
			C_Timer.After(SHOT_GAP, function() Next(i + 1) end)
		end)
	end
	local total = 0
	for _, st in ipairs(steps) do total = total + (st.wait or SHOT_WAIT) + SHOT_GAP end
	ns.Print(("taking %d screenshots: don't touch anything for about %d s."):format(#steps, math.ceil(total)))
	Next(1)
end
