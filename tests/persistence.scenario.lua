-- Per character: the guide is picked from the character's profession, progress survives
-- /reload and relog, and the tracker says where you left off.
local T = dofile(wb.dir .. "/tests/_helper.lua")
wb.state.player.level = 30
wb.state.bags[6218] = 1 -- Runed Copper Rod

wb.login({ saved = T.professionGlobals({ [T.ENCHANTING] = { name = "Enchanting", rank = 64, max = 150 } }) })
local char = wb.saved("CraftboundCharDB")
wb.expect("enchanting guide picked by itself", char.active, "Enchanting:Tried & Tested")
wb.expect("skill remembered", char.skills.Enchanting.rank, 64)
wb.advance(0.2)
wb.check(wb.shown("CraftboundTracker"), "tracker shown")
wb.check(wb.printed("Next: Craft Lesser Magic Wand"), "login message says where you are")

-- tick the disenchant step by hand, hide the tracker
wb.slash("/craft tick 2")
wb.slash("/craft tracker")
wb.advance(0.2)
wb.check(not wb.shown("CraftboundTracker"), "/craft tracker hides the tracker")

wb.reload()
char = wb.saved("CraftboundCharDB")
wb.expect("active guide survives reload", char.active, "Enchanting:Tried & Tested")
wb.check(char.guides["Enchanting:Tried & Tested"].ticks[2], "tick survives reload")
wb.expect("skill survives reload", char.skills.Enchanting.rank, 64)
wb.check(char.trackerHidden, "hidden tracker stays hidden")

-- a skill-up later: history grows
T.inject(T.professionGlobals({ [T.ENCHANTING] = { name = "Enchanting", rank = 66, max = 150 } }))
wb.fire("SKILL_LINES_CHANGED")
char = wb.saved("CraftboundCharDB")
wb.expect("new skill read", char.skills.Enchanting.rank, 66)
local h = char.guides["Enchanting:Tried & Tested"].history
wb.expect("history records the skill-up", h[#h].skill, 66)

wb.relog()
wb.slash("/craft tracker")
wb.advance(0.2)
wb.check(wb.shown("CraftboundTracker"), "/craft tracker shows it again after relog")
wb.expect("still 66 after relog", wb.saved("CraftboundCharDB").skills.Enchanting.rank, 66)

-- switch guide by command
wb.slash("/craft guide alchemy")
wb.expect("switched", wb.saved("CraftboundCharDB").active, "Alchemy:Tried & Tested")
wb.slash("/craft list")
wb.check(wb.printed("Peacebloom"), "shopping list in chat")
wb.slash("/craft reset")
wb.check(wb.saved("CraftboundCharDB").guides["Alchemy:Tried & Tested"] == nil, "reset forgets the guide's progress")

-- settings are account-wide and survive reload
wb.slash("/craft toggle select")
wb.expect("auto-select off", wb.saved("CraftboundDB").settings.autoSelect, false)
wb.reload()
wb.expect("still off after reload", wb.saved("CraftboundDB").settings.autoSelect, false)

-- a character saved on an old "Easiest" guide moves to the profession's guide, keeping its
-- history and stop (ticks were by step number, so they go)
wb.login({ saved = { CraftboundCharDB = { active = "Alchemy:Easiest", guides = {
	["Alchemy:Easiest"] = { ticks = { [4] = true }, history = { { t = 1, skill = 10 } }, target = 150 },
} } } })
char = wb.saved("CraftboundCharDB")
wb.expect("old guide moved to the new one", char.active, "Alchemy:Tried & Tested")
local moved = char.guides["Alchemy:Tried & Tested"]
wb.expect("history kept", moved and moved.history[1].skill, 10)
wb.expect("stop kept", moved and moved.target, 150)
wb.check(moved and next(moved.ticks) == nil, "ticks dropped")

-- an old guide that wasn't active also moves its history
wb.login({ saved = { CraftboundCharDB = { active = "Alchemy:Easiest", guides = {
	["Alchemy:Easiest"] = { ticks = {}, history = {} },
	["Enchanting:Easiest"] = { ticks = {}, history = { { t = 2, skill = 33 } } },
} } } })
char = wb.saved("CraftboundCharDB")
wb.check(char.guides["Enchanting:Easiest"] == nil, "old key gone")
local e2 = char.guides["Enchanting:Tried & Tested"]
wb.expect("its history moved", e2 and e2.history[1].skill, 33)
