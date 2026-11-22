-- Tailoring, Cooking and First Aid: imported from Wowhead's Forever catalog
-- (tools/import_wowhead.py): bolts as parts, vendor reagents, vendors by faction, how secondary
-- skills learn Expert and Artisan.
wb.login()
local P = wb.ns.Planner
local tail = P.Find("Tailoring:Tried & Tested")
local cook = P.Find("Cooking:Tried & Tested")
local aid = P.Find("First Aid:Tried & Tested")
wb.check(tail and cook and aid, "the three imported guides load")

local owned = {}
local function ctx(skill)
	return { skill = skill, maxSkill = 300, level = 60, ticks = {}, have = function(m)
		return owned[m.id or m.name] or 0
	end }
end
local function find(list, name)
	for _, e in ipairs(list) do if e.name == name then return e end end
end
local function step(g, recipe)
	for _, s in ipairs(g.steps) do if s.recipe == recipe then return s end end
end

-- bolts are parts: shopped as cloth, never bought as bolts
local list = P.Shopping(tail, ctx(45))
wb.check(find(list, "Bolt of Linen Cloth") == nil, "linen bolts not shopped")
wb.check(find(list, "Linen Cloth") ~= nil, "linen cloth shopped for the bolts")
wb.check(find(list, "Coarse Thread") ~= nil, "thread on the list")

-- the catalog's vendor reagents are never searched at the auction house
wb.check(wb.ns.GuideVendorItems[2692], "Hot Spices is a vendor item")
wb.check(wb.ns.AH.VENDOR_ITEMS[14341], "Rune Thread stays a vendor item")

-- Forever-only recipes keep their vendor, reputation and station
local cuffs = step(tail, "Runecloth Cuffs")
wb.expect("cuffs from Pexmit", cuffs.source.npc, "Pexmit")
wb.check(wb.ns.LearnHint(cuffs):find("Pexmit (Mount Hyjal)", 1, true), "learn hint names Pexmit")
local gloves = step(tail, "Venomspew Gloves")
wb.expect("venomspew at a loom", gloves.station, "Loom")
wb.check(wb.ns.LearnHint(gloves):find("Friendly with Cenarion Circle", 1, true), "reputation in the hint")

-- crafts per step from the skill-up model match Wowhead's table
wb.expect("runecloth cuffs crafts", cuffs.expected, 25)
wb.expect("bolt of linen crafts", step(tail, "Bolt of Linen Cloth").expected, 54)

-- vendors for this faction only
local mightfish = step(cook, "Mightfish Steak")
wb.expect("mightfish needs an oven", mightfish.station, "Iron Oven")
local bandage = step(aid, "Heavy Silk Bandage")
wb.state.player.faction = "Horde"
wb.check(wb.ns.LearnHint(bandage):find("Balai Lok'Wein", 1, true), "horde vendor for horde")
wb.check(not wb.ns.LearnHint(bandage):find("Deneb Walker", 1, true), "no alliance vendor for horde")
wb.state.player.faction = "Alliance"
wb.check(wb.ns.LearnHint(bandage):find("Deneb Walker", 1, true), "alliance vendor for alliance")
wb.check(wb.ns.LearnHint(step(aid, "Linen Bandage")):find("starting recipe", 1, true), "starter recipe")

-- secondary skills: Expert from a book, Artisan from a quest
local expert
for _, s in ipairs(cook.steps) do if s.kind == "train" and s.rank == "Expert" then expert = s end end
wb.check(P.Describe(expert):find("Expert Cookbook", 1, true), "cooking expert from the cookbook")

-- review fixes: vendor recipes flagged "starter" are still bought; Artisan for secondary skills at 225
local smallfish = step(cook, "Brilliant Smallfish")
wb.expect("smallfish is a vendor recipe", smallfish.source.kind, "vendor")
local artisan
for _, s in ipairs(aid.steps) do if s.kind == "train" and s.rank == "Artisan" then artisan = s end end
wb.expect("triage needs skill 225", artisan.reqSkill, 225)
wb.check(not P.IsReady(artisan, ctx(210)), "artisan first aid not ready at 210")
-- a recipe sold only to the other faction
local only = { recipe = "Test", source = { kind = "vendor", npc = "X", vendors = { { npc = "X", side = "Horde" } } } }
wb.check(wb.ns.LearnHint(only):find("other faction", 1, true), "other-faction-only recipe")

-- Blacksmithing 1-300 (Wowhead's Tried & Tested): the hammer is bought, a better one counts,
-- grinding stones are parts, Forever's Bold Dirk comes from Pexmit
local bs = P.Find("Blacksmithing:Tried & Tested")
wb.check(bs and bs.from == 1 and bs.to == 300, "blacksmithing 1-300 loads")
local hammerStep
for _, s in ipairs(bs.steps) do if s.kind == "tool" and s.buy then hammerStep = s end end
wb.check(hammerStep and hammerStep.recipe == "Blacksmith Hammer", "hammer is a buy step")
local hi
for i, s in ipairs(bs.steps) do if s == hammerStep then hi = i end end
owned = {}
wb.check(not P.IsDone(bs, hi, ctx(60)), "no hammer: buy one")
owned[285281] = 1 -- Arcanite Blacksmith Hammer
wb.check(P.IsDone(bs, hi, ctx(60)), "a better hammer will do")
owned = {}
wb.check(find(P.Shopping(bs, ctx(140)), "Coarse Grinding Stone") == nil, "grinding stones are parts")
wb.check(find(P.Shopping(bs, ctx(140)), "Coarse Stone") ~= nil, "shopped as stone")
local dirk = step(bs, "Bold Dirk")
wb.expect("bold dirk from Pexmit", dirk.source.npc, "Pexmit")
wb.check(dirk.mats[3] and dirk.mats[3].name == "Azerothium Bar" and dirk.mats[3].id ~= nil, "Azerothium Bar has an ID now")
