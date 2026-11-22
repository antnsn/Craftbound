-- At a rank's cap our Craft button stops, and Blizzard's Create buttons ask first.
local T = dofile(wb.dir .. "/tests/_helper.lua")
wb.state.player.level = 30
wb.state.bags[6218] = 1
wb.login({ saved = T.professionGlobals({ [T.ENCHANTING] = { name = "Enchanting", rank = 75, max = 75 } }) })
local ts = T.tradeSkill(T.ENCHANTING, "Enchanting", 75, 75, T.enchantingRecipes())
local shown = {}
T.inject({ C_TradeSkillUI = ts, StaticPopup_Show = function(which, text) shown[#shown + 1] = { which = which, text = text } end })
local pf = wb.G.CreateFrame("Frame", "ProfessionsFrame", wb.G.UIParent)
pf.CraftingPage = wb.G.CreateFrame("Frame", nil, pf)
pf.CraftingPage.SelectRecipe = function() end
local create = wb.G.CreateFrame("Button", nil, pf.CraftingPage)
create.IsEnabled = function() return true end
pf.CraftingPage.CreateButton = create
pf:Show()
wb.fire("TRADE_SKILL_SHOW")
wb.advance(0.5)

-- our own button: stopped, says why
local plan = wb.ns.CraftPlan()
wb.check(not plan.enabled, "Craft is off at 75/75")
wb.ns.CraftNext()
wb.expect("nothing crafted", #ts.calls.craft + #ts.calls.enchant, 0)

-- Blizzard's Create: our frame lies over it and asks
local guard
for _, c in ipairs({ create:GetChildren() }) do guard = c end
wb.check(guard and guard:IsShown(), "guard over Create at the cap")
guard:Click()
wb.expect("asks first", shown[1] and shown[1].which, "CRAFTBOUND_AT_CAP")
wb.check(shown[1] and shown[1].text:find("75/75", 1, true), "says the cap")
wb.ns.CapPopup.OnAccept()
wb.check(not guard:IsShown(), "craft anyway lets clicks through")

-- trained: 76/150 is not at the cap
ts.set(76, 150)
T.inject(T.professionGlobals({ [T.ENCHANTING] = { name = "Enchanting", rank = 76, max = 150 } }))
wb.fire("TRADE_SKILL_LIST_UPDATE")
wb.advance(0.3)
wb.check(not guard:IsShown(), "no guard below the cap")
-- the next cap asks again
ts.set(150, 150)
T.inject(T.professionGlobals({ [T.ENCHANTING] = { name = "Enchanting", rank = 150, max = 150 } }))
wb.fire("TRADE_SKILL_LIST_UPDATE")
wb.advance(0.3)
wb.check(guard:IsShown(), "guard again at 150/150")
-- a disabled Create button needs no guard
create.IsEnabled = function() return false end
wb.ns.UpdateCapGuard()
wb.check(not guard:IsShown(), "no guard over a disabled button")
create.IsEnabled = function() return true end
-- 300/300: crafting for the items, no question
ts.set(300, 300)
T.inject(T.professionGlobals({ [T.ENCHANTING] = { name = "Enchanting", rank = 300, max = 300 } }))
wb.fire("TRADE_SKILL_LIST_UPDATE")
wb.advance(0.3)
wb.check(not guard:IsShown(), "no guard at 300")
-- the setting turns it off
ts.set(225, 225)
T.inject(T.professionGlobals({ [T.ENCHANTING] = { name = "Enchanting", rank = 225, max = 225 } }))
wb.fire("TRADE_SKILL_LIST_UPDATE")
wb.advance(0.3)
wb.check(guard:IsShown(), "guard at 225/225")
wb.slash("/craft toggle cap")
wb.check(not guard:IsShown(), "toggle turns it off")
