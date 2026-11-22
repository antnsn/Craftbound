-- Planner: the route logic, with no WoW API in it (wowbench tests it directly).
--
-- A context describes the character:
--   ctx.skill, ctx.maxSkill   current skill and the rank's cap (maxSkill nil = unknown)
--   ctx.level                 character level
--   ctx.ticks                 [stepIndex] = true for steps the player ticked off by hand
--   ctx.have(mat)             how many of a material/tool the character owns (mat = { id, name })
--   ctx.liveMats(recipe)      optional: the recipe's real reagents seen in the profession
--                             window, a list of { id, name, qty }, or nil
--   ctx.target                optional: the skill the player wants to stop at (150, 225...).
--                             Steps past it are out of scope (counted as done), a step that
--                             crosses it is cut short. Step indices never change.
local _, ns = ...

local P = {}
ns.Planner = P

local ceil, max, min = math.ceil, math.max, math.min

function P.Find(key)
	for _, g in ipairs(ns.Guides) do
		if g.key == key then return g end
	end
end

function P.ForProfession(profession)
	local list = {}
	for _, g in ipairs(ns.Guides) do
		if g.profession == profession then list[#list + 1] = g end
	end
	return list
end

-- Where the route ends for this character: the guide's end, or the stop target below it.
function P.End(guide, ctx)
	local t = ctx and ctx.target
	return (t and t < guide.to and t > guide.from) and t or guide.to
end

-- Crafts still needed in a craft step at this skill: the guide's safe count, scaled by the part
-- of the step's range still ahead (up to the target, when there is one). Tools: one until owned.
function P.CraftsLeft(step, skill, target)
	if step.kind == "tool" then return step.safe or 1 end
	if step.kind ~= "craft" then return 0 end
	local safe = step.safe or step.expected or 0
	local from, to = step.from or 0, step.to or 0
	local stop = (target and target < to) and target or to
	local ahead = stop - max(skill, from)
	if ahead <= 0 then return 0 end
	if to <= from then return safe end
	return max(1, ceil(safe * ahead / (to - from)))
end

-- The skill-up colour of a recipe at a skill, from the guide's thresholds:
-- "red" (not learnable yet), "orange", "yellow", "green", "gray" (nil without thresholds).
function P.Color(step, skill)
	local c = step.colors
	if not c then return nil end
	if skill < c[1] then return "red" end
	if skill >= c[4] then return "gray" end
	if skill >= c[3] then return "green" end
	if skill >= c[2] then return "yellow" end
	return "orange"
end

-- Does a step need this tool in its bags?
function P.NeedsTool(s, tool)
	for _, t in ipairs(s.tools or {}) do
		if t == tool then return true end
	end
	return false
end

-- The last later step that needs this tool (crafts and tools made with it).
local function lastUser(guide, i, tool)
	local last
	for j = i + 1, #guide.steps do
		local s = guide.steps[j]
		if (s.kind == "craft" or s.kind == "tool") and P.NeedsTool(s, tool) then last = s end
	end
	return last
end

local function indexOf(guide, step)
	for j, s in ipairs(guide.steps) do
		if s == step then return j end
	end
end

-- Which steps are part of the route up to a target: { [i] = true/false }, worked out once per
-- guide and target, last step first (a tool is in scope when a later in-scope step needs it).
local scopes = setmetatable({}, { __mode = "k" })

function P.Scope(guide, target)
	local byTarget = scopes[guide]
	if not byTarget then
		byTarget = {}
		scopes[guide] = byTarget
	end
	local sc = byTarget[target]
	if sc then return sc end
	sc = {}
	local steps = guide.steps
	for i = #steps, 1, -1 do
		local s = steps[i]
		local inside = true
		if s.kind == "craft" or s.kind == "disenchant" then
			inside = (s.from or 0) < target
		elseif s.kind == "train" then
			inside = (s.before or 0) < target
		elseif s.kind == "tool" then
			local used, needed = false, false
			for j = i + 1, #steps do
				local u = steps[j]
				if (u.kind == "craft" or u.kind == "tool") and P.NeedsTool(u, s.recipe) then
					used = true
					if sc[j] then needed = true break end
				end
			end
			inside = needed or (not used and ((s.colors and s.colors[1]) or 0) < target)
		end
		sc[i] = inside
	end
	byTarget[target] = sc
	return sc
end

-- Is step i part of the route up to the target? (Always, without a target.)
function P.InScope(guide, i, target)
	if not target or target >= guide.to or target <= guide.from then return true end
	return P.Scope(guide, target)[i]
end

function P.IsDone(guide, i, ctx)
	local s = guide.steps[i]
	if ctx.ticks and ctx.ticks[i] then return true end
	if not P.InScope(guide, i, ctx.target) then return true end
	local skill = ctx.skill or 0
	if s.kind == "craft" or s.kind == "disenchant" then
		return skill >= min(s.to or 0, P.End(guide, ctx))
	elseif s.kind == "train" then
		if ctx.maxSkill and s.cap and ctx.maxSkill >= s.cap then return true end
		return skill > (s.before or 0)
	elseif s.kind == "tool" then
		if ctx.have and ctx.have({ id = s.item, name = s.recipe }) > 0 then return true end
		for _, id in ipairs(s.items or {}) do -- any of the tool's items (a better hammer)
			if ctx.have and ctx.have({ id = id }) > 0 then return true end
		end
		-- past every step that needs it (sold or replaced)
		local user = lastUser(guide, i, s.recipe)
		if not user then return false end
		if user.kind == "tool" then return P.IsDone(guide, indexOf(guide, user), ctx) end
		return skill >= min(user.to or 0, P.End(guide, ctx))
	end
	return false
end

-- Can the player act on this step now?
function P.IsReady(s, ctx)
	local skill = ctx.skill or 0
	if s.kind == "train" then
		return skill >= (s.reqSkill or 0) and (ctx.level or 0) >= (s.reqLevel or 0)
	elseif s.kind == "tool" then
		return skill >= ((s.colors and s.colors[1]) or 0)
	end
	return true
end

-- The full picture: { current = index, step = step, done = { [i] = bool }, train = step or nil,
-- trainIndex, trainUrgent = bool, left = crafts left in the current step, total = crafts left
-- in the route, finished = bool, percent = 0..1 }
function P.Status(guide, ctx)
	local skill = ctx.skill or 0
	local st = { done = {}, out = {}, total = 0, stop = P.End(guide, ctx) }
	for i, s in ipairs(guide.steps) do
		local done = P.IsDone(guide, i, ctx)
		st.done[i] = done
		st.out[i] = not P.InScope(guide, i, ctx.target) or nil
		if not done then
			if s.kind == "train" then
				if P.IsReady(s, ctx) and not st.train then
					st.train, st.trainIndex = s, i
					st.trainUrgent = skill >= (s.before or 0) - 5
				end
			else
				if not st.current and P.IsReady(s, ctx) then st.current, st.step = i, s end
				st.total = st.total + P.CraftsLeft(s, skill, ctx.target)
			end
		end
	end
	-- a rank you must train now beats everything
	if st.train and (st.trainUrgent or not st.current) then
		st.current, st.step = st.trainIndex, st.train
	end
	st.finished = st.current == nil and skill >= st.stop
	if st.step then st.left = P.CraftsLeft(st.step, skill, ctx.target) else st.left = 0 end
	local span = st.stop - guide.from
	st.percent = span > 0 and min(1, max(0, (skill - guide.from) / span)) or 1
	return st
end

local function matKey(m) return m.id or m.name end

-- A part the route makes along the way (a grinding stone, a power core), by reagent name.
function P.Part(guide, name)
	return guide.parts and name and guide.parts[name]
end

-- How many more of a part to make, and in how many crafts: { part, short, crafts } or nil.
-- have: optional count function (the bags only, when crafting); default ctx.have.
function P.PartShort(guide, mat, need, ctx, have)
	local part = P.Part(guide, mat.name)
	if not part then return nil end
	have = have or ctx.have
	have = have and have({ id = part.id or mat.id, name = mat.name }) or 0
	local short = need - have
	if short <= 0 then return nil end
	return { part = part, name = mat.name, short = short, crafts = ceil(short / (part.makes or 1)) }
end

-- What the rest of the route still needs, minus what the character owns.
-- Parts the route makes itself are replaced by their own reagents (minus the parts in bags).
-- Returns a list of { id, name, need, have, missing } sorted with the most missing first,
-- then the total of what is missing (pieces).
function P.Shopping(guide, ctx)
	local skill = ctx.skill or 0
	local need, order = {}, {}
	local function add(m, qty)
		local k = matKey(m)
		local e = need[k]
		if not e then
			e = { id = m.id, name = m.name, need = 0 }
			need[k] = e
			order[#order + 1] = e
		end
		e.id = e.id or m.id
		e.need = e.need + qty
	end
	for i, s in ipairs(guide.steps) do
		if (s.kind == "craft" or s.kind == "tool") and not P.IsDone(guide, i, ctx) then
			local n = P.CraftsLeft(s, skill, ctx.target)
			local mats = (ctx.liveMats and ctx.liveMats(s.recipe)) or s.mats or {}
			for _, m in ipairs(mats) do add(m, (m.qty or 1) * n) end
		end
	end
	-- expand parts into their reagents (parts are not made of other parts)
	local parts = {}
	for _, e in ipairs(order) do
		if P.Part(guide, e.name) then parts[#parts + 1] = e end
	end
	for _, e in ipairs(parts) do
		-- a part the route also crafts as a step of its own (Gold Power Core) comes from there
		local made = 0
		for i, s in ipairs(guide.steps) do
			if s.kind == "craft" and s.recipe == e.name and not P.IsDone(guide, i, ctx) then
				made = made + P.CraftsLeft(s, skill, ctx.target) * (s.makes or 1)
			end
		end
		local short = P.PartShort(guide, e, e.need - made, ctx)
		if short then
			for _, m in ipairs(short.part.mats or {}) do add(m, (m.qty or 1) * short.crafts) end
		end
	end
	local list, missingTotal = {}, 0
	for _, e in ipairs(order) do
		if not P.Part(guide, e.name) then
			e.have = ctx.have and ctx.have(e) or 0
			e.missing = max(0, e.need - e.have)
			missingTotal = missingTotal + e.missing
			list[#list + 1] = e
		end
	end
	table.sort(list, function(a, b)
		if (a.missing > 0) ~= (b.missing > 0) then return a.missing > 0 end
		if a.missing ~= b.missing then return a.missing > b.missing end
		return (a.name or "") < (b.name or "")
	end)
	return list, missingTotal
end

-- Trainer and vendor recipe cost still ahead (the guide's numbers, copper). A bought tool is on
-- the shopping list instead. ctx.known(recipe) (optional) skips recipes already learned.
function P.RecipeCost(guide, ctx)
	local sum = 0
	for i, s in ipairs(guide.steps) do
		local src = s.source
		if (s.kind == "craft" or s.kind == "tool") and not s.buy and not P.IsDone(guide, i, ctx)
			and src and src.cost and (src.kind == "trainer" or src.kind == "vendor")
			and not (ctx.known and ctx.known(s.recipe)) then
			sum = sum + src.cost
		end
	end
	return sum
end

-- One line describing a step, for the tracker and the panels.
function P.Describe(s, left)
	if not s then return "Route finished." end
	if s.kind == "train" then
		if s.how then return ("%s Needed before skill %d."):format(s.how, s.before) end
		return ("Train %s at a trainer (needed before skill %d)."):format(s.rank, s.before)
	elseif s.kind == "disenchant" then
		return ("Disenchant green or better items up to skill %d."):format(s.to)
	elseif s.kind == "tool" and s.buy then
		return ("Buy a %s from %s and keep it in your bags."):format(s.recipe,
			(s.source and s.source.npc) or "a vendor")
	elseif s.kind == "tool" then
		return ("Make a %s and keep it in your bags."):format(s.recipe)
	end
	return ("Craft %s x%d (to skill %d)."):format(s.recipe, left or 0, s.to)
end
