-- Blacksmithing, Engineering, Leatherworking: bought tools, several tools per step, and parts
-- made along the way (grinding stones, power cores) that Craftbound shops for and crafts first.
local T = dofile(wb.dir .. "/tests/_helper.lua")
wb.login()
local P = wb.ns.Planner
local bs = P.Find("Blacksmithing:Easiest")
local eng = P.Find("Engineering:Easiest")
local lw = P.Find("Leatherworking:Easiest")
wb.check(bs and eng and lw, "the three new guides load")
wb.expect("blacksmithing starts at 125", bs.from, 125)

local owned = {}
local function ctx(skill, maxSkill)
	return { skill = skill, maxSkill = maxSkill or 300, level = 60, ticks = {}, have = function(m)
		return owned[m.id or m.name] or 0
	end }
end
local function find(list, name)
	for _, e in ipairs(list) do if e.name == name then return e end end
end

-- no hammer: buy one first
local st = P.Status(bs, ctx(125, 150))
wb.check(st.step.buy, "first step is buying the hammer")
wb.check(P.Describe(st.step):find("Buy a Blacksmith Hammer", 1, true), "describes the purchase")
local list = P.Shopping(bs, ctx(125, 150))
wb.expect("hammer on the shopping list", find(list, "Blacksmith Hammer").missing, 1)
owned[5956] = 1
st = P.Status(bs, ctx(125, 150))
wb.expect("hammer in bags -> Iron Buckle", st.step.recipe, "Iron Buckle")

-- parts: the grinding stones are shopped as Solid Stone, never bought themselves
list = P.Shopping(bs, ctx(246))
wb.check(find(list, "Solid Grinding Stone") == nil, "grinding stone not shopped")
local stone = find(list, "Solid Stone")
-- 13 maces + 20 shivs need 33 stones of 4 Solid Stone each
wb.expect("solid stone for the grinding stones", stone.need, 33 * 4)
owned[7966] = 13
wb.expect("stones in bags cut the stone needed", find(P.Shopping(bs, ctx(246)), "Solid Stone").need, 20 * 4)
owned[7966] = nil

-- a part the route also crafts as its own step is not bought twice (Gold Power Core)
local gold = find(P.Shopping(eng, ctx(150)), "Gold Bar")
wb.expect("gold bars only for the power core step", gold.need, 27)

-- colours: below the orange threshold a recipe is red (not learnable yet)
wb.expect("red below orange", P.Color(bs.steps[#bs.steps], 125), "red")

-- engineering: the spanner stays needed until the last step that uses it
owned[6219] = nil
local spanner
for i, s in ipairs(eng.steps) do if s.recipe == "Arclight Spanner" then spanner = i end end
wb.check(not P.IsDone(eng, spanner, ctx(260)), "spanner still needed at 260")
wb.check(P.IsDone(eng, spanner, ctx(300)), "spanner retired at 300")
local gizmo
for _, s in ipairs(eng.steps) do if s.recipe == "Whirring Bronze Gizmo" then gizmo = s end end
wb.check(P.NeedsTool(gizmo, "Blacksmith Hammer") and P.NeedsTool(gizmo, "Arclight Spanner"), "two tools on one step")

-- leatherworking: the reputation and limited stock reach the step notes
local brawlers = lw.steps[#lw.steps]
wb.check(brawlers.note and brawlers.note:find("Revered with Timbermaw Hold", 1, true), "reputation note")
wb.check(wb.ns.LearnHint(brawlers):find("Revered", 1, true), "learn hint names the reputation")

-- the window: Big Black Mace needs a grinding stone, so Craft makes the stones first
wb.state.player.level = 60
wb.state.bags[5956] = 1
wb.reload({ saved = T.professionGlobals({ [164] = { name = "Blacksmithing", rank = 246, max = 300 } }) })
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
wb.expect("blacksmithing guide picked from the window", wb.ns.char.active, "Blacksmithing:Easiest")
local plan = wb.ns.CraftPlan()
wb.expect("craft makes the part first", plan.label, "Make 5 Solid Grinding Stone")
wb.ns.CraftNext()
wb.expect("crafted the grinding stone recipe", ts.calls.craft[1] and ts.calls.craft[1].id, 2002)
wb.expect("as many as the bags allow", ts.calls.craft[1] and ts.calls.craft[1].n, 5)
