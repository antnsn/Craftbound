-- The route logic on its own: current step, crafts left, ranks, tools, shopping.
wb.login()
local P = wb.ns.Planner
local ench = P.Find("Enchanting:Easiest")
local alch = P.Find("Alchemy:Easiest")
wb.check(ench and alch, "both guides load")

local owned = {}
local function ctx(skill, extra)
	local c = { skill = skill, maxSkill = 75, level = 60, ticks = {}, have = function(m)
		return owned[m.id or m.name] or 0
	end }
	for k, v in pairs(extra or {}) do c[k] = v end
	return c
end

-- skill 1, nothing owned: make the Runed Copper Rod first
local st = P.Status(ench, ctx(1))
wb.expect("first step is the rod", st.step.recipe, "Runed Copper Rod")
wb.expect("one rod", st.left, 1)

-- rod in bags: Dust to Motes
owned[6218] = 1
st = P.Status(ench, ctx(1))
wb.expect("rod owned -> dust to motes", st.step.recipe, "Dust to Motes")

owned[6218] = 1
-- skill 20: chest stamina; Journeyman not trainable yet (needs 50)
st = P.Status(ench, ctx(20))
wb.expect("skill 20 -> inferior stamina", st.step.recipe, "Enchant Chest - Inferior Stamina")
wb.expect("full safe count at the start", st.left, 62)
wb.check(st.train == nil, "no rank to train at 20")

-- skill 50: trainable, not urgent
st = P.Status(ench, ctx(50))
wb.expect("still crafting at 50", st.step.recipe, "Enchant Chest - Inferior Stamina")
wb.expect("journeyman offered", st.train and st.train.rank, "Journeyman")
wb.expect("crafts scaled to the rest of the range", st.left, math.ceil(62 * (79 - 50) / (79 - 20)))

-- skill 72 at cap 75: training comes first
st = P.Status(ench, ctx(72))
wb.expect("urgent training is the step", st.step.kind, "train")

-- trained (max 150): back to crafting
st = P.Status(ench, ctx(72, { maxSkill = 150 }))
wb.expect("trained -> crafting again", st.step.recipe, "Enchant Chest - Inferior Stamina")

-- a ticked step is skipped
st = P.Status(ench, ctx(1, { ticks = { [1] = true, [2] = true } }))
wb.expect("ticked steps skipped", st.step.kind, "disenchant")

-- colours from the guide thresholds
local s = ench.steps[5]
wb.expect("orange at 20", P.Color(s, 20), "orange")
wb.expect("yellow at 75", P.Color(s, 75), "yellow")
wb.expect("gray at 110", P.Color(s, 110), "gray")

-- shopping: Alchemy from 1, with 50 Peacebloom owned
owned = { [2447] = 50 }
local list, missing = P.Shopping(alch, ctx(1))
local pb
for _, e in ipairs(list) do if e.name == "Peacebloom" then pb = e end end
wb.expect("peacebloom need = 11 + 50 + 15 + 14", pb.need, 90)
wb.expect("peacebloom have", pb.have, 50)
wb.expect("peacebloom missing", pb.missing, 40)
wb.check(missing > 0, "something to buy")
wb.check(list[1].missing >= list[#list].missing, "most missing first")

-- live reagents replace the guide's
list = P.Shopping(alch, ctx(257, { liveMats = function(recipe)
	if recipe == "Major Discolored Healing Potion" then
		return { { id = 8845, name = "Ghost Mushroom", qty = 2 } }
	end
end }))
local gm
for _, e in ipairs(list) do if e.name == "Ghost Mushroom" then gm = e end end
wb.expect("live reagents used", gm and gm.need, 88)

-- finished
st = P.Status(alch, ctx(300, { maxSkill = 300 }))
wb.check(st.finished, "300 is finished")
wb.expect("describe finished", P.Describe(nil), "Route finished.")

-- a tool is still needed while any later step uses it
owned = {}
st = P.Status(ench, ctx(20))
wb.expect("no copper rod at 20: make it first", st.step.recipe, "Runed Copper Rod")
