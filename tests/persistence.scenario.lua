-- Per character: the guide is picked from the character's profession, progress survives
-- /reload and relog, and the tracker says where you left off.
local T = dofile(wb.dir .. "/tests/_helper.lua")
wb.state.player.level = 30
wb.state.bags[6218] = 1 -- Runed Copper Rod

wb.login({ saved = T.professionGlobals({ [T.ENCHANTING] = { name = "Enchanting", rank = 64, max = 150 } }) })
local char = wb.saved("CraftboundCharDB")
wb.expect("enchanting guide picked by itself", char.active, "Enchanting:Easiest")
wb.expect("skill remembered", char.skills.Enchanting.rank, 64)
wb.advance(0.2)
wb.check(wb.shown("CraftboundTracker"), "tracker shown")
wb.check(wb.printed("Next: Craft Enchant Chest %- Inferior Stamina"), "login message says where you are")

-- tick the disenchant step by hand, hide the tracker
wb.slash("/craft tick 3")
wb.slash("/craft tracker")
wb.advance(0.2)
wb.check(not wb.shown("CraftboundTracker"), "/craft tracker hides the tracker")

wb.reload()
char = wb.saved("CraftboundCharDB")
wb.expect("active guide survives reload", char.active, "Enchanting:Easiest")
wb.check(char.guides["Enchanting:Easiest"].ticks[3], "tick survives reload")
wb.expect("skill survives reload", char.skills.Enchanting.rank, 64)
wb.check(char.trackerHidden, "hidden tracker stays hidden")

-- a skill-up later: history grows
T.inject(T.professionGlobals({ [T.ENCHANTING] = { name = "Enchanting", rank = 66, max = 150 } }))
wb.fire("SKILL_LINES_CHANGED")
char = wb.saved("CraftboundCharDB")
wb.expect("new skill read", char.skills.Enchanting.rank, 66)
local h = char.guides["Enchanting:Easiest"].history
wb.expect("history records the skill-up", h[#h].skill, 66)

wb.relog()
wb.slash("/craft tracker")
wb.advance(0.2)
wb.check(wb.shown("CraftboundTracker"), "/craft tracker shows it again after relog")
wb.expect("still 66 after relog", wb.saved("CraftboundCharDB").skills.Enchanting.rank, 66)

-- switch guide by command
wb.slash("/craft guide alchemy")
wb.expect("switched", wb.saved("CraftboundCharDB").active, "Alchemy:Easiest")
wb.slash("/craft list")
wb.check(wb.printed("Peacebloom"), "shopping list in chat")
wb.slash("/craft reset")
wb.check(wb.saved("CraftboundCharDB").guides["Alchemy:Easiest"] == nil, "reset forgets the guide's progress")

-- settings are account-wide and survive reload
wb.slash("/craft toggle select")
wb.expect("auto-select off", wb.saved("CraftboundDB").settings.autoSelect, false)
wb.reload()
wb.expect("still off after reload", wb.saved("CraftboundDB").settings.autoSelect, false)
