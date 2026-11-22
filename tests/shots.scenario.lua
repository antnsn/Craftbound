-- /craft shots: each frame in turn, a screenshot each, where it sat saved for crop_shots.py;
-- nothing saved or left open afterwards.
local T = dofile(wb.dir .. "/tests/_helper.lua")
wb.login({ saved = T.professionGlobals({ [T.ENCHANTING] = { name = "Enchanting", rank = 60, max = 75 } }) })
local taken = 0
T.inject({ Screenshot = function() taken = taken + 1 end })
local customBefore = #wb.ns.db.custom
wb.slash("/craft shots")
wb.advance(30)
local run = wb.ns.db.shots and wb.ns.db.shots.craftbound
wb.check(run ~= nil, "run saved under the addon's own skin")
local names = {}
for _, s in ipairs(run and run.list or {}) do names[#names + 1] = s.name end
wb.expect("the frames shot", table.concat(names, ","), "window,window-editor,export,tracker")
wb.expect("one screenshot per frame", taken, 4)
for _, s in ipairs(run and run.list or {}) do
	wb.check(s.rects and s.rects.main, s.name .. " has its place on screen")
end
wb.expect("the editor saved nothing", #wb.ns.db.custom, customBefore)
wb.check(not wb.shown("CraftboundWindow"), "window closed afterwards")
wb.check(not wb.shown("CraftboundShare"), "export box closed afterwards")
wb.check(wb.printed("crop_shots.py Craftbound"), "says how to cut them out")
wb.check(wb.printed("Open a profession window"), "says how to get the panels too")

-- with a profession it can open: the profession window is opened, shot and closed again
local ts = T.tradeSkill(T.ENCHANTING, "Enchanting", 60, 75, T.enchantingRecipes())
local opened, closed = 0, 0
ts.OpenTradeSkill = function()
	opened = opened + 1
	local pf = wb.G.ProfessionsFrame or wb.G.CreateFrame("Frame", "ProfessionsFrame", wb.G.UIParent)
	pf.CraftingPage = pf.CraftingPage or { SelectRecipe = function() end }
	pf:Show()
	wb.fire("TRADE_SKILL_SHOW")
end
ts.CloseTradeSkill = function() closed = closed + 1 end
T.inject({ C_TradeSkillUI = ts })
taken = 0
wb.slash("/craft shots")
wb.advance(30)
run = wb.ns.db.shots.craftbound
names = {}
for _, s in ipairs(run.list) do names[#names + 1] = s.name end
wb.expect("profession window shot too", table.concat(names, ","), "window,window-editor,export,tracker,profession-window")
wb.expect("opened once", opened, 1)
wb.expect("closed again", closed, 1)
