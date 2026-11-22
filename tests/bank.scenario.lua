-- Reagents in the bank count for shopping, and the panel, Craft and the tracker say to fetch them.
local T = dofile(wb.dir .. "/tests/_helper.lua")
wb.state.player.level = 30
wb.state.bags[6218] = 1 -- Runed Copper Rod
local bank = { [10938] = 40 } -- Lesser Magic Essence, all in the bank
wb.login({ saved = T.professionGlobals({ [T.ENCHANTING] = { name = "Enchanting", rank = 30, max = 75 } }) })
T.inject({ C_Item = setmetatable({
	GetItemCount = function(id, withBank)
		return (wb.state.bags[id] or 0) + (withBank and bank[id] or 0)
	end,
}, { __index = wb.G.C_Item }) })
wb.state.bags[4470] = 60 -- Simple Wood in the bags
local ts = T.tradeSkill(T.ENCHANTING, "Enchanting", 30, 75, T.enchantingRecipes({ craftable = 0 }))
T.inject({ C_TradeSkillUI = ts })
local pf = wb.G.CreateFrame("Frame", "ProfessionsFrame", wb.G.UIParent)
pf.CraftingPage = { SelectRecipe = function() end }
pf:Show()
wb.fire("TRADE_SKILL_SHOW")
wb.advance(0.5)

-- shopping: the bank's essences count
local list = wb.ns.Planner.Shopping(wb.ns.ActiveGuide(), wb.ns.Context(wb.ns.ActiveGuide()))
local lme
for _, e in ipairs(list) do if e.name == "Lesser Magic Essence" then lme = e end end
wb.expect("bank counted as owned", lme and lme.have, 40)

-- Craft says where they are
local plan = wb.ns.CraftPlan()
wb.check(not plan.enabled, "can't craft from the bank")
wb.check(plan.reason and plan.reason:find("Lesser Magic Essence (40 in the bank)", 1, true), "says to fetch: " .. tostring(plan.reason))

-- the panel's reagent row and the tracker say it too
wb.ns.Fire("CB_REFRESH")
local panel = wb.frame("CraftboundProfessionPanel")
local found
for _, r in ipairs(panel.mats.rows) do
	if r:IsShown() and (r.text:GetText() or ""):find("in bank", 1, true) then found = true end
end
wb.check(found, "reagent row says in bank")
wb.check((wb.ns.tracker.extra:GetText() or ""):find("Fetch: Lesser Magic Essence", 1, true), "tracker says fetch")
