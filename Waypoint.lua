-- Waypoints: where to go for what the route needs next, from the NPCs in NpcData.lua (QuestieDB).
--   /craft way          the most useful one: a rank to train, the current recipe to learn, a vendor
--                       reagent you're missing, else your profession's trainer
--   /craft way trainer | recipe | vendor
-- Sets the map's own waypoint (super-tracked) and a TomTom one when TomTom is loaded. Only NPCs
-- on your side and your continent count; distance is in a straight line.
local _, ns = ...

local P = ns.Planner

local RANK_TIER = { Journeyman = 1, Expert = 2, Artisan = 3 }

local function Safe(fn, ...)
	if type(fn) ~= "function" then return nil end
	local r = { pcall(fn, ...) }
	if not r[1] then return nil end
	return unpack(r, 2, table.maxn(r))
end

local function Friendly(side)
	if not side or side == "AH" then return true end
	local mine = Safe(UnitFactionGroup, "player")
	return (mine == "Alliance" and side == "A") or (mine == "Horde" and side == "H")
end

-- world position of an NPC entry, worked out once
local function World(v)
	if v.cont == nil then
		local cont, world = Safe(C_Map.GetWorldPosFromMapPos, v.map, CreateVector2D(v.x, v.y))
		if world then
			v.cont, v.wx, v.wy = cont, world:GetXY()
		else
			v.cont = false
		end
	end
	return v.cont
end

local function Here()
	local map = Safe(C_Map.GetBestMapForUnit, "player")
	if not map then return nil end
	local pos = Safe(C_Map.GetPlayerMapPosition, map, "player")
	if not pos then return nil end
	local cont, world = Safe(C_Map.GetWorldPosFromMapPos, map, pos)
	if not world then return nil end
	local wx, wy = world:GetXY()
	return cont, wx, wy
end

-- the nearest of a list of NPC entries: entry, yards; or nil, "nowhere" | "none"
local function Nearest(list)
	local cont, px, py = Here()
	if not cont then return nil, "nowhere" end
	local best, bestD
	for _, v in ipairs(list) do
		if Friendly(v.side) and World(v) == cont then
			local d = (v.wx - px) ^ 2 + (v.wy - py) ^ 2
			if not bestD or d < bestD then best, bestD = v, d end
		end
	end
	if not best then return nil, "none" end
	return best, math.floor(math.sqrt(bestD) + 0.5)
end
ns.NearestNPC = Nearest

local NPC = function() return ns.NPC or { trainers = {}, npcs = {}, sells = {} } end

-- trainers of a profession who teach at least to a tier (1 Journeyman, 2 Expert, 3 Artisan)
local function Trainers(profession, tier)
	local out = {}
	for _, v in ipairs(NPC().trainers[profession] or {}) do
		if (v.tier or 1) >= (tier or 1) then out[#out + 1] = v end
	end
	return out
end

-- the tier a recipe needs from its skill: Journeyman trainers teach to 150, Expert to 225
local function TierFor(skill)
	skill = skill or 0
	if skill >= 225 then return 3 end
	if skill >= 150 then return 2 end
	return 1
end

-- the vendors of a step's recipe, as NPC entries
local function RecipeVendors(s)
	local out, src = {}, s.source or {}
	local function add(id)
		local v = id and NPC().npcs[id]
		if v then out[#out + 1] = v end
	end
	add(src.npcID)
	for _, v in ipairs(src.vendors or {}) do add(v.id) end
	return out
end

-- vendors selling a reagent the route still misses
local function SupplyVendors(guide, ctx)
	local out, seen, what = {}, {}, {}
	for _, e in ipairs((P.Shopping(guide, ctx))) do
		local id = e.missing > 0 and ns.ItemID(e)
		for _, npc in ipairs(id and NPC().sells[id] or {}) do
			local v = NPC().npcs[npc]
			if v and not seen[npc] then
				seen[npc] = true
				out[#out + 1] = v
			end
		end
		if id and NPC().sells[id] then what[#what + 1] = e.name end
	end
	return out, what
end

-- What a waypoint should point at: { label, list, why } for a kind, or the best one.
function ns.WayPlan(kind)
	local st, ctx, guide = ns.Status()
	if not guide then return nil, "Pick a guide first (/craft)." end
	local plans = {}
	-- a rank to train: the one you can train now, else the next one on the route
	local train = st.train or (st.step and st.step.kind == "train" and st.step)
	if not train then
		for i, x in ipairs(guide.steps) do
			if x.kind == "train" and not P.IsDone(guide, i, ctx) then train = x break end
		end
	end
	if train and not train.how then
		plans.trainer = { label = ("a %s trainer for %s"):format(guide.profession, train.rank),
			list = Trainers(guide.profession, RANK_TIER[train.rank]), urgent = st.step == train }
	end
	-- the current recipe, not learned yet
	local s = st.step
	if s and (s.kind == "craft" or s.kind == "tool") and not s.buy and not ns.char.known[s.recipe] then
		local live = ns.OpenRecipe(s.recipe)
		if not (live and live.learned ~= false) then
			local src = s.source or {}
			if src.kind == "vendor" then
				plans.recipe = { label = ("the %s recipe vendor"):format(s.recipe), list = RecipeVendors(s) }
			elseif src.kind == "trainer" or not src.kind then
				plans.recipe = { label = ("a trainer for %s"):format(s.recipe),
					list = Trainers(guide.profession, TierFor(s.from or (s.colors and s.colors[1]))) }
			end
		end
	end
	-- vendor reagents you are missing
	local list, what = SupplyVendors(guide, ctx)
	if #list > 0 then
		plans.vendor = { label = "a vendor for " .. table.concat(what, ", "), list = list }
	end
	-- any trainer of the profession, as the last resort
	plans.any = { label = ("a %s trainer"):format(guide.profession), list = Trainers(guide.profession, 1) }
	if kind then
		if kind == "trainer" then return plans.trainer or plans.any end
		return plans[kind]
	end
	if plans.trainer and plans.trainer.urgent then return plans.trainer end
	return plans.recipe or plans.vendor or plans.trainer or plans.any
end

local WHY = {
	nowhere = "can't tell where you are here (inside a dungeon?).",
	none = "none on your side of this continent.",
}

function ns.Waypoint(kind)
	local plan, why = ns.WayPlan(kind)
	if not plan then return ns.Print(why or ("nothing to go to for '" .. tostring(kind) .. "' right now.")) end
	local v, yards = Nearest(plan.list)
	if not v then return ns.Print(("No waypoint for %s: %s"):format(plan.label, WHY[yards] or "")) end
	local set = false
	if Safe(C_Map.CanSetUserWaypointOnMap, v.map) then
		local point = Safe(UiMapPoint.CreateFromCoordinates, v.map, v.x, v.y)
		if point and pcall(C_Map.SetUserWaypoint, point) then
			set = true
			if C_SuperTrack then pcall(C_SuperTrack.SetSuperTrackedUserWaypoint, true) end
		end
	end
	local tomtom = rawget(_G, "TomTom")
	if type(tomtom) == "table" and type(tomtom.AddWaypoint) == "function" then
		local ok, uid = pcall(tomtom.AddWaypoint, tomtom, v.map, v.x, v.y, { title = v.name, from = "Craftbound" })
		set = set or (ok and uid ~= nil)
	end
	local info = Safe(C_Map.GetMapInfo, v.map)
	ns.Print(("%s: %s, %s (%.1f, %.1f), %d yards. %s"):format(plan.label, v.name, info and info.name or "?",
		v.x * 100, v.y * 100, yards, set and "Waypoint set." or "No waypoint here: look for it on the map."))
	return v
end
