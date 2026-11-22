-- Planner: the route logic, with no WoW API in it (wowbench tests it directly).
--
-- A context describes the character:
--   ctx.skill, ctx.maxSkill   current skill and the rank's cap (maxSkill nil = unknown)
--   ctx.level                 character level
--   ctx.ticks                 [stepIndex] = true for steps the player ticked off by hand
--   ctx.have(mat)             how many of a material/tool the character owns (mat = { id, name })
--   ctx.liveMats(recipe)      optional: the recipe's real reagents seen in the profession
--                             window, a list of { id, name, qty }, or nil
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

-- Crafts still needed in a craft step at this skill: the guide's safe count, scaled by the part
-- of the step's range still ahead. Tools: one until owned.
function P.CraftsLeft(step, skill)
	if step.kind == "tool" then return step.safe or 1 end
	if step.kind ~= "craft" then return 0 end
	local safe = step.safe or step.expected or 0
	local from, to = step.from or 0, step.to or 0
	if skill >= to then return 0 end
	if skill <= from or to <= from then return safe end
	return max(1, ceil(safe * (to - skill) / (to - from)))
end

-- The skill-up colour of a recipe at a skill, from the guide's thresholds:
-- "orange", "yellow", "green", "gray" (nil without thresholds).
function P.Color(step, skill)
	local c = step.colors
	if not c then return nil end
	if skill >= c[4] then return "gray" end
	if skill >= c[3] then return "green" end
	if skill >= c[2] then return "yellow" end
	return "orange"
end

-- The last later craft step that needs this tool.
local function lastUser(guide, i, tool)
	local last
	for j = i + 1, #guide.steps do
		local s = guide.steps[j]
		if s.kind == "craft" and s.tool == tool then last = s end
	end
	return last
end

function P.IsDone(guide, i, ctx)
	local s = guide.steps[i]
	if ctx.ticks and ctx.ticks[i] then return true end
	local skill = ctx.skill or 0
	if s.kind == "craft" or s.kind == "disenchant" then
		return skill >= (s.to or 0)
	elseif s.kind == "train" then
		if ctx.maxSkill and s.cap and ctx.maxSkill >= s.cap then return true end
		return skill > (s.before or 0)
	elseif s.kind == "tool" then
		if ctx.have and ctx.have({ id = s.item, name = s.recipe }) > 0 then return true end
		-- past every step that needs it (sold or replaced)
		local user = lastUser(guide, i, s.recipe)
		return user ~= nil and skill >= (user.to or 0)
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
	local st = { done = {}, total = 0 }
	for i, s in ipairs(guide.steps) do
		local done = P.IsDone(guide, i, ctx)
		st.done[i] = done
		if not done then
			if s.kind == "train" then
				if P.IsReady(s, ctx) and not st.train then
					st.train, st.trainIndex = s, i
					st.trainUrgent = skill >= (s.before or 0) - 5
				end
			else
				if not st.current and P.IsReady(s, ctx) then st.current, st.step = i, s end
				st.total = st.total + P.CraftsLeft(s, skill)
			end
		end
	end
	-- a rank you must train now beats everything
	if st.train and (st.trainUrgent or not st.current) then
		st.current, st.step = st.trainIndex, st.train
	end
	st.finished = st.current == nil and skill >= guide.to
	if st.step then st.left = P.CraftsLeft(st.step, skill) else st.left = 0 end
	local span = guide.to - guide.from
	st.percent = span > 0 and min(1, max(0, (skill - guide.from) / span)) or 1
	return st
end

local function matKey(m) return m.id or m.name end

-- What the rest of the route still needs, minus what the character owns.
-- Returns a list of { id, name, need, have, missing } sorted with the most missing first,
-- then the total of what is missing (pieces).
function P.Shopping(guide, ctx)
	local skill = ctx.skill or 0
	local need, order = {}, {}
	for i, s in ipairs(guide.steps) do
		if (s.kind == "craft" or s.kind == "tool") and not P.IsDone(guide, i, ctx) then
			local n = P.CraftsLeft(s, skill)
			local mats = (ctx.liveMats and ctx.liveMats(s.recipe)) or s.mats or {}
			for _, m in ipairs(mats) do
				local k = matKey(m)
				local e = need[k]
				if not e then
					e = { id = m.id, name = m.name, need = 0 }
					need[k] = e
					order[#order + 1] = e
				end
				e.id = e.id or m.id
				e.need = e.need + (m.qty or 1) * n
			end
		end
	end
	local list, missingTotal = {}, 0
	for _, e in ipairs(order) do
		e.have = ctx.have and ctx.have(e) or 0
		e.missing = max(0, e.need - e.have)
		missingTotal = missingTotal + e.missing
		list[#list + 1] = e
	end
	table.sort(list, function(a, b)
		if (a.missing > 0) ~= (b.missing > 0) then return a.missing > 0 end
		if a.missing ~= b.missing then return a.missing > b.missing end
		return (a.name or "") < (b.name or "")
	end)
	return list, missingTotal
end

-- Trainer/vendor cost still ahead (the guide's raw numbers, copper).
function P.RecipeCost(guide, ctx)
	local sum = 0
	for i, s in ipairs(guide.steps) do
		if (s.kind == "craft" or s.kind == "tool") and not P.IsDone(guide, i, ctx)
			and s.source and s.source.cost and s.source.kind == "trainer" then
			sum = sum + s.source.cost
		end
	end
	return sum
end

-- One line describing a step, for the tracker and the panels.
function P.Describe(s, left)
	if not s then return "Route finished." end
	if s.kind == "train" then
		return ("Train %s at a trainer (needed before skill %d)."):format(s.rank, s.before)
	elseif s.kind == "disenchant" then
		return ("Disenchant green or better items up to skill %d."):format(s.to)
	elseif s.kind == "tool" then
		return ("Make a %s and keep it in your bags."):format(s.recipe)
	end
	return ("Craft %s x%d (to skill %d)."):format(s.recipe, left or 0, s.to)
end
