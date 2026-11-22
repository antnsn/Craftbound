-- /craft way: the nearest NPC on your side and continent for what the route needs next.
local T = dofile(wb.dir .. "/tests/_helper.lua")
local s = wb.state
s.player.level = 30
s.player.faction = "Horde"
s.pos = { map = 1411, x = 0.50, y = 0.50 } -- Durotar
s.bags[6218] = 1                         -- Runed Copper Rod
wb.login({ saved = T.professionGlobals({ [T.ENCHANTING] = { name = "Enchanting", rank = 72, max = 75 } }) })
local ns = wb.ns
ns.NPC = {
	trainers = { Enchanting = {
		{ npc = 1, name = "Near Journeyman", map = 1411, x = 0.52, y = 0.48, side = "H", tier = 1 },
		{ npc = 2, name = "Far Expert", map = 1411, x = 0.90, y = 0.90, side = "H", tier = 2 },
		{ npc = 3, name = "Alliance Expert", map = 1411, x = 0.50, y = 0.51, side = "A", tier = 2 },
		{ npc = 4, name = "Elwynn Artisan", map = 1429, x = 0.50, y = 0.50, side = "AH", tier = 3 },
	} },
	npcs = { [9001] = { npc = 9001, name = "Wood Seller", map = 1411, x = 0.55, y = 0.55, side = "AH" } },
	sells = { [4470] = { 9001 } }, -- Simple Wood
}

-- at 72/75 training is the step: the nearest Journeyman trainer
wb.slash("/craft way")
wb.check(wb.printed("Near Journeyman"), "nearest trainer named")
wb.expect("waypoint on the map", s.waypoint and s.waypoint.uiMapID, 1411)
wb.check(s.superTracked, "and tracked")

-- the wand needs Simple Wood from a vendor
wb.slash("/craft way vendor")
wb.check(wb.printed("Wood Seller"), "vendor for a missing vendor reagent")

-- at 130/150 Expert: only an Expert trainer on your side (not the nearer Alliance one)
T.inject(T.professionGlobals({ [T.ENCHANTING] = { name = "Enchanting", rank = 130, max = 150 } }))
wb.fire("SKILL_LINES_CHANGED")
s.bags[6339] = 1 -- Runed Silver Rod
wb.slash("/craft way trainer")
wb.check(wb.printed("Far Expert"), "expert trainer on your side")
wb.check(not wb.printed("Alliance Expert"), "not the other side's")

-- no trainer good enough on this continent: says so
T.inject(T.professionGlobals({ [T.ENCHANTING] = { name = "Enchanting", rank = 205, max = 225 } }))
wb.fire("SKILL_LINES_CHANGED")
wb.slash("/craft way trainer")
wb.check(wb.printed("none on your side of this continent"), "artisan trainer only on another continent")

-- inside an instance: can't tell where you are
s.pos = { map = 999, x = 0.5, y = 0.5 }
wb.slash("/craft way trainer")
wb.check(wb.printed("can't tell where you are"), "no position, no waypoint")

