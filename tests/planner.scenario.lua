-- The route logic on its own: current step, crafts left, ranks, tools, shopping.
wb.login()
local P = wb.ns.Planner
local ench = P.Find("Enchanting:Tried & Tested")
local alch = P.Find("Alchemy:Tried & Tested")
wb.check(ench and alch, "both guides load")

local owned = {}
local function ctx(skill, extra)
	local c = { skill = skill, maxSkill = 75, level = 60, ticks = {}, have = function(m)
		return owned[m.id or m.name] or 0
	end }
	for k, v in pairs(extra or {}) do c[k] = v end
	return c
end
local function step(g, recipe)
	for _, s in ipairs(g.steps) do if s.recipe == recipe then return s end end
end
local wand = step(ench, "Lesser Magic Wand") -- 20-79

-- skill 1, nothing owned: make the Runed Copper Rod first
local st = P.Status(ench, ctx(1))
wb.expect("first step is the rod", st.step.recipe, "Runed Copper Rod")
wb.expect("one rod", st.left, 1)

-- rod in bags: disenchant to 20
owned[6218] = 1
st = P.Status(ench, ctx(1))
wb.expect("rod owned -> disenchant", st.step.kind, "disenchant")

-- skill 20: the wand; Journeyman not trainable yet (needs 50)
st = P.Status(ench, ctx(20))
wb.expect("skill 20 -> lesser magic wand", st.step.recipe, "Lesser Magic Wand")
wb.expect("full safe count at the start", st.left, wand.safe)
wb.check(st.train == nil, "no rank to train at 20")

-- skill 50: trainable, not urgent
st = P.Status(ench, ctx(50))
wb.expect("still crafting at 50", st.step.recipe, "Lesser Magic Wand")
wb.expect("journeyman offered", st.train and st.train.rank, "Journeyman")
wb.expect("crafts scaled to the rest of the range", st.left, math.ceil(wand.safe * (79 - 50) / (79 - 20)))

-- skill 72 at cap 75: training comes first
st = P.Status(ench, ctx(72))
wb.expect("urgent training is the step", st.step.kind, "train")

-- trained (max 150): back to crafting
st = P.Status(ench, ctx(72, { maxSkill = 150 }))
wb.expect("trained -> crafting again", st.step.recipe, "Lesser Magic Wand")

-- ticked steps are skipped
st = P.Status(ench, ctx(1, { ticks = { [1] = true, [2] = true } }))
wb.expect("ticked steps skipped", st.step.recipe, "Lesser Magic Wand")

-- colours from the guide thresholds (10, 75, 95, 115)
wb.expect("orange at 20", P.Color(wand, 20), "orange")
wb.expect("yellow at 75", P.Color(wand, 75), "yellow")
wb.expect("gray at 115", P.Color(wand, 115), "gray")
wb.expect("red below 10", P.Color(wand, 5), "red")

-- shopping: Alchemy from 1, with 50 Peacebloom owned
local want = 0
for _, s in ipairs(alch.steps) do
	for _, m in ipairs(s.mats or {}) do
		if m.name == "Peacebloom" then want = want + s.safe * m.qty end
	end
end
owned = { [2447] = 50 }
local list, missing = P.Shopping(alch, ctx(1))
local pb
for _, e in ipairs(list) do if e.name == "Peacebloom" then pb = e end end
wb.check(want > 50, "the route uses peacebloom")
wb.expect("peacebloom need is every step's safe count", pb.need, want)
wb.expect("peacebloom have", pb.have, 50)
wb.expect("peacebloom missing", pb.missing, want - 50)
wb.check(missing > 0, "something to buy")
wb.check(list[1].missing >= list[#list].missing, "most missing first")

-- live reagents replace the guide's
local mdh = step(alch, "Major Discolored Healing Potion")
list = P.Shopping(alch, ctx(257, { liveMats = function(recipe)
	if recipe == "Major Discolored Healing Potion" then
		return { { id = 8845, name = "Ghost Mushroom", qty = 2 } }
	end
end }))
local gm
for _, e in ipairs(list) do if e.name == "Ghost Mushroom" then gm = e end end
wb.expect("live reagents used", gm and gm.need, 2 * mdh.safe)

-- finished
st = P.Status(alch, ctx(300, { maxSkill = 300 }))
wb.check(st.finished, "300 is finished")
wb.expect("describe finished", P.Describe(nil), "Route finished.")

-- a tool is still needed while any later step uses it
owned = {}
st = P.Status(ench, ctx(20))
wb.expect("no copper rod at 20: make it first", st.step.recipe, "Runed Copper Rod")
