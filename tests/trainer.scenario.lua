-- At the profession trainer: only what the route needs, up to the stop, is trained.
local T = dofile(wb.dir .. "/tests/_helper.lua")
wb.state.player.level = 30
wb.state.player.money = 1000000
wb.state.bags[6218], wb.state.bags[6339] = 1, 1 -- copper and silver rods in bags
wb.login({ saved = T.professionGlobals({ [T.ENCHANTING] = { name = "Enchanting", rank = 135, max = 150 } }) })

local trainer = {
	{ "Enchanting", "Expert", "available", 5000 },
	{ "Greater Magic Wand", nil, "available", 200 },            -- a step already passed (101-110)
	{ "Enchant Boots - Minor Speed", nil, "available", 800 },   -- not on the route
	{ "Enchant Bracer - Lesser Stamina", nil, "available", 1500 }, -- the step now (135-155)
	{ "Runed Silver Rod", nil, "available", 1000 },             -- a tool already in bags
	{ "Runed Golden Rod", nil, "unavailable", 2500 },           -- later (150)
	{ "Enchant Bracer - Minor Stamina", nil, "used", 250 },     -- known
}
local bought = {}
T.inject({
	IsTradeskillTrainer = function() return true end,
	GetNumTrainerServices = function() return #trainer end,
	GetTrainerServiceInfo = function(i) local s = trainer[i] return s[1], s[2], s[3] end,
	GetTrainerServiceCost = function(i) return trainer[i][4] end,
	BuyTrainerService = function(i) bought[#bought + 1] = trainer[i][1] .. (trainer[i][2] and (":" .. trainer[i][2]) or "") end,
})
wb.G.CreateFrame("Frame", "ClassTrainerFrame", wb.G.UIParent):Show()
wb.fire("TRAINER_SHOW")
wb.advance(0.2)
wb.check(wb.shown("CraftboundTrainerPanel"), "panel beside the trainer")
local plan = wb.ns.TrainerPlan()
wb.expect("enchanting guide found", plan.guide.profession, "Enchanting")
local now = {}
for _, r in ipairs(plan.now) do now[#now + 1] = r.entry.rank and (r.entry.rank .. " " .. r.entry.name) or r.entry.name end
table.sort(now)
wb.expect("only what the route needs now", table.concat(now, ","), "Enchant Bracer - Lesser Stamina,Expert Enchanting")
wb.expect("its cost", plan.cost, 6500)
local later
for _, r in ipairs(plan.rows) do if r.entry.name == "Runed Golden Rod" then later = r end end
wb.expect("the golden rod comes later", later and later.state, "later")

wb.ns.TrainRoute()
table.sort(bought)
wb.expect("trained just those", table.concat(bought, ","), "Enchant Bracer - Lesser Stamina,Enchanting:Expert")
wb.fire("TRAINER_UPDATE") -- the trainer's list catches up

-- stopping at 150: the golden rod (for 156 on) is not on the route any more
wb.slash("/craft stop 150")
plan = wb.ns.TrainerPlan()
local gold
for _, r in ipairs(plan.rows) do if r.entry.name == "Runed Golden Rod" then gold = r end end
wb.check(gold == nil, "nothing past the stop")

-- not enough money: nothing is bought
bought = {}
wb.state.player.money = 100
wb.ns.TrainRoute()
wb.expect("no money, no training", #bought, 0)
wb.check(wb.printed("costs"), "says what it costs")

-- not a profession trainer: no panel
T.inject({ IsTradeskillTrainer = function() return false end })
wb.fire("TRAINER_UPDATE")
wb.check(not wb.shown("CraftboundTrainerPanel"), "no panel at a class trainer")
wb.fire("TRAINER_CLOSED")

-- a second click before the trainer's list updates buys nothing again
wb.state.player.money = 1000000
T.inject({ IsTradeskillTrainer = function() return true end })
wb.fire("TRAINER_SHOW")
bought = {}
wb.ns.TrainRoute()
local first = #bought
wb.ns.TrainRoute()
wb.expect("no double purchase", #bought, first)
wb.fire("TRAINER_UPDATE")

-- a rank listed as one name only counts on the profession's own skill line
local P2 = wb.ns.Planner
trainer[1] = { "Expert Enchanting", nil, "available", 5000 }
T.inject({ GetTrainerServiceSkillLine = function(i) return i == 1 and "Enchanting" or nil end })
wb.slash("/craft stop end")
plan = wb.ns.TrainerPlan()
local expert
for _, r in ipairs(plan.rows) do if r.entry.rank == "Expert" then expert = r end end
wb.expect("one-name rank matched on its skill line", expert and expert.state, "train")
T.inject({ GetTrainerServiceSkillLine = function() return "Tailoring" end })
plan = wb.ns.TrainerPlan()
for _, r in ipairs(plan.rows) do if r.entry.rank == "Expert" then expert = r end end
wb.check(expert.state ~= "train", "not on another profession's line")

-- the trainer's filter hides known lines: said, not "not taught here"
T.inject({ GetTrainerServiceTypeFilter = function(t) return t == "available" end })
trainer[7] = nil
plan = wb.ns.TrainerPlan()
local states = {}
for _, r in ipairs(plan.rows) do states[r.state] = true end
wb.check(not states.elsewhere, "nothing called not taught here behind a filter")
local _ = P2

-- Forever's trainer window: a recipe the character can learn, not marked "available" by the
-- client, is trained when its skill and level requirements are met
trainer = {
	{ "Enchant Bracer - Lesser Stamina", nil, "unavailable", 1500, 130, 1 },
	{ "Runed Golden Rod", nil, "unavailable", 2500, 150, 1 },
}
T.inject({
	GetTrainerServiceTypeFilter = function() return true end,
	GetTrainerServiceSkillReq = function(i) return "Enchanting", trainer[i][5], nil end,
	GetTrainerServiceLevelReq = function(i) return trainer[i][6] end,
	GetTrainerServiceSkillLine = function() return "Enchanting" end,
})
T.inject(T.professionGlobals({ [T.ENCHANTING] = { name = "Enchanting", rank = 135, max = 150 } }))
wb.fire("SKILL_LINES_CHANGED")
wb.state.player.money = 1000000
wb.fire("TRAINER_UPDATE")
plan = wb.ns.TrainerPlan()
local st = {}
for _, r in ipairs(plan.rows) do st[r.entry.name] = r.state end
wb.expect("skill 130 met at 135: train now", st["Enchant Bracer - Lesser Stamina"], "train")
wb.expect("skill 150 not met: later", st["Runed Golden Rod"], "later")
bought = {}
wb.ns.TrainRoute()
wb.expect("bought the one it can learn", table.concat(bought, ","), "Enchant Bracer - Lesser Stamina")
wb.slash("/craft trainerinfo")
wb.check(wb.printed("Lesser Stamina | nil | unavailable | skill 130"), "trainerinfo prints the raw answers")

-- Forever names ranks after the trainer ("Journeyman Alchemist"), without a skill line
T.inject({ GetTrainerServiceSkillLine = function() return nil end })
local wants = { kind = "rank", name = "Enchanting", rank = "Expert" }
trainer = { { "Expert Enchanter", nil, "unavailable", 5000, 125, 20 }, { "Expert Tailor", nil, "available", 5000, 125, 20 } }
wb.fire("TRAINER_UPDATE")
plan = wb.ns.TrainerPlan()
local ex
for _, r in ipairs(plan.rows) do if r.entry.rank == "Expert" then ex = r end end
wb.expect("Expert Enchanter is the rank", ex and ex.service and ex.service.name, "Expert Enchanter")
local _ = wants
