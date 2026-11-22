-- Blacksmithing and Engineering: bought and made tools, parts made along the way (also parts made
-- of other parts), and Craft making the parts first.
local T = dofile(wb.dir .. "/tests/_helper.lua")
wb.login()
local P = wb.ns.Planner
local bs = P.Find("Blacksmithing:Tried & Tested")
local eng = P.Find("Engineering:Tried & Tested")
wb.check(bs and eng, "the guides load")

local owned = {}
local function ctx(skill, maxSkill)
	return { skill = skill, maxSkill = maxSkill or 300, level = 60, ticks = {}, have = function(m)
		return owned[m.id or m.name] or 0
	end }
end
local function find(list, name)
	for _, e in ipairs(list) do if e.name == name then return e end end
end
local function step(g, recipe)
	for i, s in ipairs(g.steps) do if s.recipe == recipe then return s, i end end
end

-- engineering at 238: Hi-Explosive Bombs need casings, a trigger and powder; the trigger is made
-- of powder too. Everything comes down to bars, cloth and stone.
local bomb = step(eng, "Hi-Explosive Bomb")
owned[6219], owned[5956] = 1, 1 -- spanner and hammer
local list = P.Shopping(eng, ctx(238))
for _, part in ipairs({ "Unstable Trigger", "Solid Blasting Powder", "Mithril Casing" }) do
	wb.check(find(list, part) == nil, part .. " is not bought")
end
wb.expect("solid stone: 2 powder + 1 trigger's powder, 2 stone each", find(list, "Solid Stone").need, bomb.safe * 6)
wb.expect("mithril: 2 casings of 3 + 1 trigger", find(list, "Mithril Bar").need, bomb.safe * 7)
local casing = eng.parts["Mithril Casing"].id
owned[casing] = 5 -- casings in bags
wb.expect("casings in bags cut the bars", find(P.Shopping(eng, ctx(238)), "Mithril Bar").need, bomb.safe * 7 - 5 * 3)
owned[casing] = nil

-- the spanner stays needed until the last step that uses it
owned[6219] = nil
local _, spanner = step(eng, "Arclight Spanner")
wb.check(not P.IsDone(eng, spanner, ctx(260)), "spanner still needed at 260")
wb.check(P.IsDone(eng, spanner, ctx(300)), "spanner retired at 300")
local gizmo = step(eng, "Whirring Bronze Gizmo")
wb.check(P.NeedsTool(gizmo, "Blacksmith Hammer") and P.NeedsTool(gizmo, "Arclight Spanner"), "two tools on one step")

-- colours: below the orange threshold a recipe is red (not learnable yet)
wb.expect("red below orange", P.Color(bs.steps[#bs.steps], 125), "red")

-- the window: Big Black Mace needs a grinding stone, so Craft makes the stones first
wb.state.player.level = 60
wb.state.bags[5956] = 1
wb.reload()
T.inject(T.professionGlobals({ [164] = { name = "Blacksmithing", rank = 246, max = 300 } }))
local ts = T.tradeSkill(164, "Blacksmithing", 246, 300, {
	{ id = 2001, name = "Big Black Mace", mats = { { 3860, 16 }, { 7971, 1 }, { 1210, 4 }, { 7966, 1 }, { 4304, 2 } }, craftable = 0 },
	{ id = 2002, name = "Solid Grinding Stone", mats = { { 7912, 4 } }, craftable = 5 },
})
T.inject({ C_TradeSkillUI = ts })
local pf = wb.G.CreateFrame("Frame", "ProfessionsFrame", wb.G.UIParent)
pf.CraftingPage = { SelectRecipe = function() end }
pf:Show()
wb.fire("TRADE_SKILL_SHOW")
wb.advance(0.5)
wb.expect("blacksmithing guide picked from the window", wb.ns.char.active, "Blacksmithing:Tried & Tested")
local plan = wb.ns.CraftPlan()
wb.expect("craft makes the part first", plan.label, "Make 5 Solid Grinding Stone")
wb.ns.CraftNext()
wb.expect("crafted the grinding stone recipe", ts.calls.craft[1] and ts.calls.craft[1].id, 2002)
wb.expect("as many as the bags allow", ts.calls.craft[1] and ts.calls.craft[1].n, 5)

-- review fixes ---------------------------------------------------------------------------
local ns = wb.ns
P = ns.Planner
eng = P.Find("Engineering:Tried & Tested")
local ench = P.Find("Enchanting:Tried & Tested")
-- a vendor-sold reagent is bought, not made (Mote of Magic for the first rod)
owned = {}
local elist = P.Shopping(ench, ctx(1))
wb.check(find(elist, "Mote of Magic") ~= nil, "Mote of Magic is shopped")
wb.check(ench.parts == nil or ench.parts["Mote of Magic"] == nil, "and not a part")
-- an alternative spanner counts
local _, sp = step(eng, "Arclight Spanner")
owned[282550] = 1
wb.check(P.IsDone(eng, sp, ctx(60)), "the other spanner item counts")
owned = {}
-- part recipes still to learn are in the recipe cost
local c0 = P.RecipeCost(eng, ctx(150))
local c1 = P.RecipeCost(eng, { skill = 150, maxSkill = 300, level = 60, ticks = {}, have = ctx(150).have,
	known = function(r) return r == "Heavy Blasting Powder" end })
wb.check(c0 > c1, "unlearned part recipes cost something")

-- the Craft button: nested parts and parts not learned yet
wb.reload()
T.inject(T.professionGlobals({ [202] = { name = "Engineering", rank = 238, max = 300 } }))
wb.state.bags[5956], wb.state.bags[6219] = 1, 1
local ets = T.tradeSkill(202, "Engineering", 238, 300, {
	-- the bomb's own powder is left out: the only way to the powder is through the trigger
	{ id = 3001, name = "Hi-Explosive Bomb", mats = { { 10561, 2 }, { 10560, 1 } }, craftable = 0 },
	{ id = 3002, name = "Unstable Trigger", mats = { { 3860, 1 }, { 4338, 1 }, { 10505, 1 } }, craftable = 0 },
	{ id = 3003, name = "Solid Blasting Powder", mats = { { 7912, 2 } }, craftable = 3 },
	{ id = 3004, name = "Mithril Casing", mats = { { 3860, 3 } }, craftable = 0 },
})
T.inject({ C_TradeSkillUI = ets })
wb.fire("TRADE_SKILL_SHOW")
wb.advance(0.5)
wb.expect("engineering active", wb.ns.char.active, "Engineering:Tried & Tested")
local eplan = wb.ns.CraftPlan()
wb.check(eplan.label:find("Solid Blasting Powder", 1, true), "makes the powder a part needs: " .. tostring(eplan.label))

wb.fire("TRADE_SKILL_CLOSE")
T.inject(T.professionGlobals({ [202] = { name = "Engineering", rank = 160, max = 225 } }))
local sheep = T.tradeSkill(202, "Engineering", 160, 225, {
	{ id = 3101, name = "Explosive Sheep", mats = { { 4382, 1 }, { 4375, 1 }, { 4377, 2 }, { 2592, 2 } }, craftable = 0 },
	{ id = 3102, name = "Heavy Blasting Powder", mats = { { 2838, 1 } }, craftable = 0, learned = false },
	{ id = 3103, name = "Bronze Framework", mats = { { 2841, 2 } }, craftable = 0 },
	{ id = 3104, name = "Whirring Bronze Gizmo", mats = { { 2841, 2 } }, craftable = 0 },
})
T.inject({ C_TradeSkillUI = sheep })
wb.fire("TRADE_SKILL_SHOW")
wb.advance(0.5)
local splan = wb.ns.CraftPlan()
wb.check(not splan.enabled and (splan.reason or ""):find("Learn Heavy Blasting Powder", 1, true),
	"says to learn the part's recipe: " .. tostring(splan.reason))
