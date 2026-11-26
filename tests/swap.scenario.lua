--@moods: swap back grey many stale edited
-- Use another recipe: right-click a step in the route list and pick any learned recipe that still
-- gives skill-ups; the route, the reagents and Craft follow it. "Back to" undoes it.
local T = dofile(wb.dir .. "/tests/_helper.lua")
local m = wb.mood
local s = wb.state
s.player.level = 30
s.bags[10940] = 30 -- Strange Dust
s.bags[6218] = 1   -- Runed Copper Rod
wb.login({ saved = T.professionGlobals({ [T.ENCHANTING] = { name = "Enchanting", rank = 79, max = 150 } }) })
local recipes = T.enchantingRecipes()
local spirit = { id = 1006, name = "Enchant Bracer - Minor Spirit", mats = { { 10940, 1 } }, craftable = 30,
	enchant = true, difficulty = 1 }
recipes[#recipes + 1] = spirit
recipes[#recipes + 1] = { id = 1007, name = "Enchant Boots - Old Grey One", mats = { { 10940, 1 } }, craftable = 30,
	enchant = true, difficulty = 3 }
if m == "many" then -- more than fit: the mouse wheel reaches the rest
	for i = 1, 25 do
		recipes[#recipes + 1] = { id = 2000 + i, name = ("Enchant Gloves - Test %02d"):format(i), mats = { { 10940, 1 } },
			craftable = 5, enchant = true, difficulty = 2 }
	end
end
local ts = T.tradeSkill(T.ENCHANTING, "Enchanting", 79, 150, recipes)
T.inject({
	C_TradeSkillUI = ts,
	Enum = { TradeskillRecipeType = { Enchant = 3 } },
	ItemLocation = {
		CreateFromEquipmentSlot = function(_, slot) return { slot = slot, IsValid = function() return true end } end,
	},
})
local pf = wb.G.CreateFrame("Frame", "ProfessionsFrame", wb.G.UIParent)
pf.CraftingPage = { SelectRecipe = function() end }
pf:Show()
wb.fire("TRADE_SKILL_SHOW")
wb.advance(0.5)

local function need(id)
	for _, e in ipairs(wb.ns.Planner.Shopping(wb.ns.ActiveGuide(), select(2, wb.ns.Status()))) do
		if e.id == id then return e.need end
	end
	return 0
end
local essenceBefore = need(10938)
local st = wb.ns.Status()
local orig = st.step.recipe
wb.expect("the step today", orig, "Enchant Chest - Minor Absorption")
local panel = wb.frame("CraftboundProfessionPanel")
local row
for _, r in ipairs(panel.route.rows) do if r:IsShown() and r.index == st.current then row = r end end
wb.check(row ~= nil, "the step's line in the route list")
row:GetScript("OnClick")(row, "RightButton")
wb.check(wb.shown("CraftboundSwapPicker"), "right-click opens the recipe picker")
local picker = wb.frame("CraftboundSwapPicker")
local function shown()
	local out = {}
	for _, r in ipairs(picker.rows.rows) do if r:IsShown() then out[r.recipe or "?"] = r end end
	return out
end
local names = shown()
if m == "many" then
	wb.check(not names["Enchant Gloves - Test 25"], "the last one doesn't fit at first")
	for _ = 1, 10 do picker:GetScript("OnMouseWheel")(picker, -1) end
	wb.check(shown()["Enchant Gloves - Test 25"], "the mouse wheel brings it up")
	local n = 0
	for _ in pairs(shown()) do n = n + 1 end
	wb.check(picker:GetHeight() >= 30 + 16 * n + 30, "the picker holds its rows and the note: " .. picker:GetHeight())
	return
end
if m == "stale" then
	-- the picker is open for Enchanting; the active guide becomes Alchemy before the click
	local alchKey = wb.ns.Planner.ForProfession("Alchemy")[1].key
	wb.ns.char.active = alchKey
	wb.ns.open = nil -- the Enchanting window closed
	names[spirit.name]:GetScript("OnClick")(names[spirit.name])
	local alch = wb.ns.char.guides[alchKey]
	wb.check(not (alch and alch.swaps and next(alch.swaps)), "a stale pick never lands on another guide")
	wb.expect("and the picker closes", wb.shown("CraftboundSwapPicker"), false)
	return
end
wb.check(names[spirit.name], "a learned recipe that gives skill-ups is offered")
wb.check(not names["Enchant Boots - Old Grey One"], "a grey one is not")
wb.check(not names["Enchant Bracer - Minor Stamina"], "an unlearned one is not")
wb.check(not names[orig], "nor the step's own recipe")
names[spirit.name]:GetScript("OnClick")(names[spirit.name])
wb.advance(0.2)

st = wb.ns.Status()
wb.expect("the step uses the pick", st.step.recipe, spirit.name)
wb.expect("not the old recipe's tool (the window knows what the pick needs)", st.step.tools, nil)
wb.expect("nor how many the old recipe made", st.step.makes, nil)
wb.expect("its reagents", st.step.mats and st.step.mats[1] and st.step.mats[1].id, 10940)
wb.check(row.text:GetText():find("Minor Spirit", 1, true), "the route list shows it")
wb.ns.CraftNext()
local cast = ts.calls.enchant[#ts.calls.enchant]
wb.expect("Craft enchants with it", cast and cast.id, 1006)
wb.expect("on the bracer slot", cast and cast.loc.slot, 9)

if m == "edited" then
	-- a custom guide edited since (its revision changed): the picks, like the ticks, start over
	local key = wb.ns.char.active
	wb.ns.char.guides[key].rev = "an older revision"
	wb.expect("the pick is gone after an edit", wb.ns.Status().step.recipe, orig)
	return
end
if m == "back" then
	row:GetScript("OnClick")(row, "RightButton")
	local back
	for _, r in ipairs(picker.rows.rows) do if r:IsShown() and r.back then back = r end end
	wb.check(back ~= nil, "a Back to row")
	back:GetScript("OnClick")(back)
	wb.advance(0.2)
	wb.expect("the guide's recipe again", wb.ns.Status().step.recipe, orig)
elseif m == "grey" then
	spirit.difficulty = 3
	wb.fire("TRADE_SKILL_LIST_UPDATE")
	wb.advance(0.2)
	local plan = wb.ns.CraftPlan()
	wb.check(not plan.enabled, "a pick gone grey: no crafting")
	wb.check(plan.reason and plan.reason:find("grey", 1, true), "says why: " .. tostring(plan.reason))
end

-- the shopping list follows the pick: Strange Dust for Minor Spirit, less Lesser Magic Essence
if m == "swap" then
	wb.check(need(10940) > 0, "the shopping list has the pick's reagent")
	wb.check(need(10938) < essenceBefore, "and less of the old recipe's: " .. need(10938) .. " < " .. essenceBefore)
end
