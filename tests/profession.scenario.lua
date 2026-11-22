-- The profession window: the panel docks, the step's recipe is selected, real reagents are
-- remembered, and Craft crafts the right amount (enchants go on the equipped item).
local T = dofile(wb.dir .. "/tests/_helper.lua")
wb.state.player.level = 30
wb.state.bags[10940] = 30 -- Strange Dust
wb.state.bags[6218] = 1   -- Runed Copper Rod

wb.login({ saved = T.professionGlobals({ [T.ENCHANTING] = { name = "Enchanting", rank = 20, max = 75 } }) })
local ts = T.tradeSkill(T.ENCHANTING, "Enchanting", 20, 75, T.enchantingRecipes())
local selected = {}
local loc = { IsValid = function() return true end }
T.inject({
	C_TradeSkillUI = ts,
	Enum = { TradeskillRecipeType = { Enchant = 3 } },
	ItemLocation = { CreateFromEquipmentSlot = function(_, slot) loc.slot = slot return loc end },
})
local pf = wb.G.CreateFrame("Frame", "ProfessionsFrame", wb.G.UIParent)
pf.CraftingPage = { SelectRecipe = function(_, info) selected[#selected + 1] = info.name end }
pf:Show()

wb.fire("TRADE_SKILL_SHOW")
wb.advance(0.5)
wb.check(wb.shown("CraftboundProfessionPanel"), "panel docked to the profession window")
wb.expect("step recipe selected", selected[#selected], "Lesser Magic Wand")
local rec = wb.saved("CraftboundDB").recipes["Lesser Magic Wand"]
wb.expect("recipe id remembered", rec and rec.id, 1003)
wb.check(not rec.enchant, "a wand is not an enchant")
local mote = wb.saved("CraftboundDB").recipes["Runed Copper Rod"].mats[2]
wb.expect("unknown reagent gets an id", mote.id, 99001)

-- craft the wand: as many as the window allows and the step needs
local plan = wb.ns.CraftPlan()
wb.check(plan.enabled, "craft enabled: " .. tostring(plan.reason))
wb.ns.CraftNext()
wb.check(ts.calls.craft[1] and ts.calls.craft[1].id == 1003, "wand crafted")

-- skill 79: Minor Absorption is an enchant, it goes on the chest
ts.set(79, 150)
T.inject(T.professionGlobals({ [T.ENCHANTING] = { name = "Enchanting", rank = 79, max = 150 } }))
wb.fire("TRADE_SKILL_LIST_UPDATE")
wb.advance(0.2)
wb.ns.CraftNext()
wb.expect("one enchant cast", #ts.calls.enchant, 1)
wb.expect("on the chest slot", loc.slot, 5)

-- the game asks to replace the enchant: the next press answers it
local replaced = 0
T.inject({ C_Item = setmetatable({ ReplaceEnchant = function() replaced = replaced + 1 end }, { __index = wb.G.C_Item }) })
wb.fire("REPLACE_ENCHANT", "Old", "New")
wb.expect("button offers the replace", wb.ns.CraftPlan().label, "Replace enchant")
wb.ns.CraftNext()
wb.expect("replace answered", replaced, 1)

-- skill moves to 90: next recipe is not learned -> disabled with a reason
ts.set(90, 150)
T.inject(T.professionGlobals({ [T.ENCHANTING] = { name = "Enchanting", rank = 90, max = 150 } }))
wb.fire("TRADE_SKILL_LIST_UPDATE")
wb.advance(0.2)
plan = wb.ns.CraftPlan()
wb.check(not plan.enabled, "unlearned recipe can't be crafted")
wb.check(plan.reason and plan.reason:find("Learn Enchant Bracer %- Minor Stamina"), "says to learn it: " .. tostring(plan.reason))

-- a non-enchant profession: Alchemy crafts min(left, craftable) in one go
wb.fire("TRADE_SKILL_CLOSE")
local alch = T.tradeSkill(T.ALCHEMY, "Alchemy", 1, 75, {
	{ id = 2001, name = "Elixir of Minor Force", mats = { { 765, 1 }, { 3371, 1 } }, craftable = 7 },
})
T.inject({ C_TradeSkillUI = alch })
wb.fire("TRADE_SKILL_SHOW")
wb.advance(0.5)
wb.expect("alchemy guide follows the window", wb.saved("CraftboundCharDB").active, "Alchemy:Tried & Tested")
wb.ns.CraftNext()
wb.expect("crafts what it can", alch.calls.craft[1] and alch.calls.craft[1].n, 7)

-- a batch never runs past the rank's cap: 68/75 on Elixir of Minor Fortitude (65-90) -> 7
wb.fire("TRADE_SKILL_CLOSE")
local capped = T.tradeSkill(T.ALCHEMY, "Alchemy", 68, 75, {
	{ id = 2003, name = "Elixir of Minor Fortitude", mats = { { 2449, 2 }, { 2447, 1 }, { 3371, 1 } }, craftable = 40 },
})
T.inject({ C_TradeSkillUI = capped })
T.inject(T.professionGlobals({ [T.ALCHEMY] = { name = "Alchemy", rank = 68, max = 75 } }))
wb.fire("TRADE_SKILL_SHOW")
wb.advance(0.5)
local cp = wb.ns.CraftPlan()
wb.expect("capped batch", cp.label, "Craft 7")

-- at the cap: train first
capped.set(75)
wb.fire("TRADE_SKILL_LIST_UPDATE")
wb.advance(0.2)
cp = wb.ns.CraftPlan()
wb.check(not cp.enabled, "no crafting at the cap")

-- vendor recipes say where to buy them
local smp
for _, s in ipairs(wb.ns.Planner.Find("Alchemy:Tried & Tested").steps) do
	if s.recipe == "Superior Mana Potion" then smp = s end
end
wb.state.player.faction = "Horde"
local hint = wb.ns.LearnHint(smp)
wb.check(hint:find("Buy the Superior Mana Potion recipe from", 1, true) and hint:find("limited stock", 1, true), "vendor hint: " .. hint)

-- the route list shows a window of steps around the current one
local panel = wb.frame("CraftboundProfessionPanel")
wb.ns.Fire("CB_REFRESH")
local rows = 0
for _, r in ipairs(panel.route.rows) do if r:IsShown() then rows = rows + 1 end end
wb.check(rows <= 10 and rows > 0, "route rows bounded: " .. rows)
