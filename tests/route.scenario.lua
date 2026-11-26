-- The route list with a stop target: only the steps up to the stop, then one line for the rest
-- (no row of "past your stop" names cut off at the edge).
local T = dofile(wb.dir .. "/tests/_helper.lua")
wb.state.player.level = 30
wb.state.bags[10940] = 30
wb.state.bags[6218] = 1
wb.login({ saved = T.professionGlobals({ [T.ENCHANTING] = { name = "Enchanting", rank = 79, max = 150 } }) })
local ts = T.tradeSkill(T.ENCHANTING, "Enchanting", 79, 150, T.enchantingRecipes())
T.inject({ C_TradeSkillUI = ts, Enum = { TradeskillRecipeType = { Enchant = 3 } } })
local pf = wb.G.CreateFrame("Frame", "ProfessionsFrame", wb.G.UIParent)
pf.CraftingPage = { SelectRecipe = function() end }
pf:SetSize(600, 900)
pf:Show()
wb.fire("TRADE_SKILL_SHOW")
wb.advance(0.5)
local key = wb.ns.ActiveGuide().key
wb.ns.SetTarget(key, 150)
wb.ns.Refresh()
wb.advance(0.2)

local panel = wb.frame("CraftboundProfessionPanel")
local texts, summary = {}, nil
for _, r in ipairs(panel.route.rows) do
	if r:IsShown() then
		local t = r.text:GetText() or ""
		texts[#texts + 1] = t
		if r.summary then summary = t end
	end
end
for _, t in ipairs(texts) do
	wb.check(not t:find("past your stop", 1, true), "no 'past your stop' rows: " .. t)
end
wb.check(summary and summary:find("After your stop at 150", 1, true), "one line for the rest: " .. tostring(summary))
local st = wb.ns.Status()
local after = 0
for i in pairs(st.out) do if st.out[i] then after = after + 1 end end
wb.check(summary and summary:find(after .. " more steps", 1, true), "it counts them: " .. after)

-- clicking the line opens the window on this guide (where the stop is set), even after browsing another
local shownKey
local show = wb.ns.Window.Show
wb.ns.Window.Show = function(k) shownKey = k return show(k) end
for _, r in ipairs(panel.route.rows) do
	if r:IsShown() and r.summary then r:GetScript("OnClick")(r, "LeftButton") end
end
wb.expect("the window opens on the active guide", shownKey, key)
