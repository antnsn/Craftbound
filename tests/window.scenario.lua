-- The Craftbound window: stop targets cut the route, prices give a cost per target, guides are
-- copied, edited, deleted, exported and imported as text (parsed as data, sanitised).
local T = dofile(wb.dir .. "/tests/_helper.lua")
wb.login({ saved = T.professionGlobals({ [333] = { name = "Enchanting", rank = 132, max = 150 } }) })
local ns = wb.ns
local P = ns.Planner
local ench = P.Find("Enchanting:Tried & Tested")

-- targets ---------------------------------------------------------------------------------
local function ctx(skill, target)
	return { skill = skill, maxSkill = 300, level = 60, ticks = {}, target = target, have = function() return 0 end }
end
local function idx(recipe)
	for i, s in ipairs(ench.steps) do if s.recipe == recipe then return i, s end end
end
local ci, cross = idx("Enchant Bracer - Lesser Stamina") -- 135-155
wb.expect("a step crossing the stop is cut", P.CraftsLeft(cross, 132, 150), math.ceil(cross.safe * 15 / 20))
local gi = idx("Enchant Bracer - Lesser Strength") -- 156-185
wb.check(not P.InScope(ench, gi, 150), "a step past the stop is out")
wb.check(P.IsDone(ench, gi, ctx(132, 150)), "out-of-scope steps count as done")
local expert
for i, s in ipairs(ench.steps) do if s.kind == "train" and s.rank == "Expert" then expert = i end end
wb.check(not P.InScope(ench, expert, 150), "no Expert needed to stop at 150")
wb.check(not P.InScope(ench, idx("Runed Golden Rod"), 150), "a tool only needed past the stop is out")
wb.check(P.InScope(ench, idx("Runed Silver Rod"), 150), "a tool needed before the stop stays")
local st = P.Status(ench, ctx(150, 150))
wb.check(st.finished, "finished at the stop")
wb.expect("progress ends at the stop", st.stop, 150)
local _, all = P.Shopping(ench, ctx(132))
local _, to150 = P.Shopping(ench, ctx(132, 150))
wb.check(to150 < all, "shopping to 150 is less than to 300")
wb.check(ci and true, "found the crossing step")

wb.slash("/craft guide enchanting")
wb.slash("/craft stop 150")
wb.expect("stop saved per character", ns.char.guides["Enchanting:Tried & Tested"].target, 150)
wb.expect("targets offered", table.concat(ns.Targets(ench), ","), "150,225,300")
wb.expect("blacksmithing offers its stops", table.concat(ns.Targets(P.Find("Blacksmithing:Tried & Tested")), ","), "150,225,300")
wb.slash("/craft stop end")
wb.expect("stop cleared", ns.char.guides["Enchanting:Tried & Tested"].target, nil)

-- prices ----------------------------------------------------------------------------------
local Pr = ns.Prices
wb.expect("vendor price from the catalog", (Pr.Unit({ id = 3371 })), 18)
Pr.Remember(10940, 250)
local unit, src = Pr.Unit({ id = 10940 })
wb.expect("own scan price", unit, 250)
wb.expect("own scan source", src, "scan")
wb.G.Auctionator = { API = { v1 = {
	GetAuctionPriceByItemID = function(_, id) return id == 11083 and 900 or nil end,
	GetAuctionAgeByItemID = function() return 1 end,
} } }
local u2, s2 = Pr.Unit({ id = 11083 })
wb.expect("Auctionator price", u2, 900)
wb.expect("Auctionator source", s2, "auctionator")
local c150 = Pr.CostTo(ench, 150)
local c300 = Pr.CostTo(ench, 300)
wb.check(c150.copper > 0 and c300.copper > c150.copper, "300 costs more than 150")
wb.check(c300.unpriced > 0, "items without a price are counted")
wb.check(Pr.Describe(c300):find("without a price", 1, true), "and said")

-- share -----------------------------------------------------------------------------------
local S = ns.Share
local text = S.Export(ench)
wb.check(text:sub(1, 4) == "CB1:", "export starts with CB1:")
local back = S.Import(text)
wb.check(back and #back.steps == #ench.steps, "import gives the same steps")
wb.expect("reagents survive", back.steps[ci].mats[1].name, cross.mats[1].name)
wb.expect("colours survive", back.steps[ci].colors[4], cross.colors[4])
wb.check(S.Import("hello") == nil, "not a guide")
wb.check(S.Import(text:sub(1, #text - 20)) == nil, "a cut string is refused")
local evil = S.Import("CB1:" .. S.Encode64(S.Serialize({ profession = "Alchemy", name = "x|cffff0000y",
	steps = { { kind = "craft", from = 1, to = 5, recipe = "Hack", mats = { { name = "A", qty = 1 } }, run = "os.exit()" } } })))
wb.check(evil and evil.name == "xcffff0000y", "UI escapes stripped from names")
wb.check(evil and evil.steps[1].run == nil, "unknown fields dropped")
local many = { profession = "Alchemy", name = "big", steps = {} }
for i = 1, 301 do many.steps[i] = { kind = "craft", from = 1, to = 2, recipe = "r" } end
wb.check(S.Import("CB1:" .. S.Encode64(S.Serialize(many))) == nil, "too many steps refused")

-- custom guides ---------------------------------------------------------------------------
local C = ns.Custom
local copy = C.CopyOf(ench)
wb.expect("copy is custom:1", copy.key, "custom:1")
wb.check(P.Find("custom:1") ~= nil, "copy joins the guides")
local draft = C.Copy(copy)
draft.name = "Cheap enchanting"
table.remove(draft.steps) -- drop the last step (295-300)
local saved = C.Save("custom:1", draft)
wb.expect("renamed", saved.name, "Cheap enchanting")
wb.check(saved.to < 300, "range follows the steps")
ns.SetActive("custom:1")
wb.reload()
local again = wb.ns.Planner.Find("custom:1")
wb.check(again and again.name == "Cheap enchanting", "custom guide kept after reload")
wb.expect("still active after reload", wb.ns.char.active, "custom:1")
ns = wb.ns
wb.check(ns.Custom.Delete("custom:1"), "deleted")
wb.check(ns.Planner.Find("custom:1") == nil, "gone from the guides")
wb.expect("no longer active", ns.char.active, nil)

-- the window ------------------------------------------------------------------------------
wb.slash("/craft")
wb.check(wb.shown("CraftboundWindow"), "/craft opens the window")
ns.Window.Show("Enchanting:Tried & Tested")
local win = wb.G.CraftboundWindow
wb.check(win.details:IsShown(), "details shown")
win.details.targets[1]:Click()
wb.expect("first target button stops at 150", ns.char.guides["Enchanting:Tried & Tested"].target, 150)
win.details.export:Click()
wb.check(wb.shown("CraftboundShare"), "export opens the share box")
local box = wb.G.CraftboundShare.box
wb.check((box:GetText() or ""):sub(1, 4) == "CB1:", "with the guide text")
-- import what was exported
ns.Window.ShowShare()
box:SetText(text)
wb.G.CraftboundShare.action:Click()
local imported
for _, g in ipairs(ns.Guides) do if g.custom and g.profession == "Enchanting" then imported = g end end
wb.check(imported ~= nil, "import makes a custom guide")
wb.check(not wb.shown("CraftboundShare"), "share box closes")
-- edit it in the window: rename and save
ns.Window.Edit(imported.key)
wb.check(win.editor:IsShown(), "editor shown")
win.editor.nameBox:SetText("Mine")
win.editor.save:Click()
wb.expect("saved from the editor", ns.Planner.Find(imported.key).name, "Mine")
-- a new guide needs the profession window
ns.open = nil
ns.Window.NewGuide()
wb.check(not win.editor:IsShown(), "no new guide without a profession window")

-- a new guide from the open Tailoring window: pick recipes, reagents from the schematic
local ts = T.tradeSkill(197, "Tailoring", 40, 75, {
	{ id = 3001, name = "Bolt of Linen Cloth", mats = { { 2589, 2 } }, craftable = 10 },
	{ id = 3002, name = "Linen Belt", mats = { { 2996, 1 }, { 2320, 1 } }, craftable = 0 },
})
T.inject({ C_TradeSkillUI = ts })
wb.fire("TRADE_SKILL_SHOW")
wb.advance(0.5)
wb.expect("tailoring window open", ns.open and ns.open.profession, "Tailoring")
ns.Window.NewGuide()
wb.check(win.editor:IsShown(), "new guide editor")
local pick = win.editor.picks.rows[1]
wb.check(pick and pick:IsShown(), "recipes of the open window listed")
pick:Click()
win.editor.picks.rows[2]:Click()
win.editor.save:Click()
local mine
for _, g in ipairs(ns.Guides) do if g.custom and g.profession == "Tailoring" then mine = g end end
wb.check(mine ~= nil, "new tailoring guide saved")
wb.expect("two steps", mine and #mine.steps, 2)
wb.expect("second step starts where the first ends", mine and mine.steps[2].from, mine and mine.steps[1].to)
wb.expect("reagents from the schematic", mine and mine.steps[1].mats[1].id, 2589)

-- review fixes -----------------------------------------------------------------------------
-- a chain of tools (each needing the two before) is worked out once, not exponentially
local chain = { key = "chain", profession = "Alchemy", name = "chain", from = 1, to = 300, steps = {} }
for i = 1, 40 do
	chain.steps[i] = { kind = "tool", recipe = "T" .. i, colors = { 200, 210, 220, 230 },
		tools = i > 2 and { "T" .. (i - 1), "T" .. (i - 2) } or nil }
end
local t0 = os.clock()
P.Status(chain, ctx(1, 150))
wb.check(os.clock() - t0 < 0.5, "tool chains stay fast")

-- a stop at or below the guide's start is ignored
wb.expect("stop below the start ignored", P.End({ from = 150, to = 225 }, { target = 150 }), 225)

-- the editor refuses a step it would lose
ns.Window.Edit(mine.key)
local d = win.editor
local before = #mine.steps
-- clear the first step's To box as a player would
d.rows.rows[1].to:SetText("")
d.rows.rows[1].to:GetScript("OnTextChanged")(d.rows.rows[1].to, true)
d.save:Click()
wb.check(win.editor:IsShown(), "save refused, still editing")
wb.check((win.msg:GetText() or ""):find("Step 1", 1, true), "says which step")
wb.expect("nothing lost", #ns.Planner.Find(mine.key).steps, before)
-- clicking another guide while editing keeps the draft
win.left.rows.rows[1]:Click()
wb.check(win.editor:IsShown(), "draft kept when clicking another guide")
d.cancel:Click()

-- hand ticks are cleared when an edited guide's steps change
ns.SetActive(mine.key)
ns.Tick(1, true)
local draft2 = ns.Custom.Copy(ns.Planner.Find(mine.key))
draft2.steps[1], draft2.steps[2] = draft2.steps[2], draft2.steps[1]
draft2.steps[1].from, draft2.steps[1].to, draft2.steps[2].from, draft2.steps[2].to = 1, 5, 5, 10
ns.Custom.Save(mine.key, draft2)
wb.expect("ticks cleared after an edit", ns.GuideState(mine.key).ticks[1], nil)

-- Auctionator counts whole days: our scan from today wins over its "today"
ns.Prices.Remember(11083, 777)
wb.expect("same-day scan beats Auctionator", (ns.Prices.Unit({ id = 11083 })), 777)

-- import errors read well
local _, why = ns.Share.Import("CB1:" .. ns.Share.Encode64("tq"))
wb.check(why and not why:find("Share.lua", 1, true), "no file names in import errors")

-- /craft stop with a stop the guide doesn't offer
ns.SetActive("Enchanting:Tried & Tested")
ns.SetTarget("Enchanting:Tried & Tested", nil)
wb.slash("/craft stop 175")
wb.expect("odd stop refused", ns.char.guides["Enchanting:Tried & Tested"].target, nil)
