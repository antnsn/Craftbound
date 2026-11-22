-- Tracker: a small movable box that says where you left off, anywhere in the world.
local _, ns = ...

local UI = ns.UI
local P = ns.Planner

local tracker

local function build()
	local f = UI.Panel("CraftboundTracker", UIParent, 250, 92)
	local pos = ns.char.tracker
	if pos then
		f:SetPoint(pos.point, UIParent, pos.point, pos.x, pos.y)
	else
		f:SetPoint("RIGHT", UIParent, "RIGHT", -60, 120)
	end
	f:SetFrameStrata("LOW")
	UI.Movable(f, function() return ns.char end, "tracker")

	f.title = UI.Text(f, nil, UI.GOLD)
	f.title:SetPoint("TOPLEFT", 8, -6)
	f.title:SetWidth(186)
	f.logo = UI.TitleLogo(f, f.title, 16)
	f.close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
	f.close:SetSize(20, 20)
	f.close:SetPoint("TOPRIGHT", -1, -1)
	f.close:SetScript("OnClick", function()
		ns.char.trackerHidden = true
		f:Hide()
		ns.Print("Tracker hidden. /craft brings it back.")
	end)
	f.bar = UI.Bar(f, 234, 10)
	f.bar:SetPoint("TOPLEFT", 8, -24)
	f.step = UI.Text(f, "small", { 1, 1, 1 })
	f.step:SetPoint("TOPLEFT", 8, -38)
	f.step:SetWidth(234)
	f.extra = UI.Text(f, "small", { 0.8, 0.8, 0.8 })
	f.extra:SetPoint("TOPLEFT", f.step, "BOTTOMLEFT", 0, -3)
	f.extra:SetWidth(234)
	UI.Tooltip(f, function(tip)
		tip:AddLine("Craftbound")
		tip:AddLine("Drag to move. Open your profession window to craft, the auction house to shop.", nil, nil, nil, true)
		tip:AddLine("/craft guide  pick another guide\n/craft list  shopping list in chat", 0.5, 0.8, 1, true)
	end)
	return f
end

local function render()
	if not tracker then return end
	local guide = ns.ActiveGuide()
	local want = guide and ns.db.settings.tracker and not ns.char.trackerHidden
	tracker:SetShown(want and true or false)
	if not want then return end
	local st, ctx = ns.Status(guide)
	tracker.title:SetText(("Craftbound · %s %d/%d"):format(guide.profession, ctx.skill, st.stop))
	tracker.bar:SetValue(st.percent)
	if st.finished then
		tracker.step:SetText(UI.Color("green", "Route finished!"))
		tracker.extra:SetText("")
	else
		tracker.step:SetText(P.Describe(st.step, st.left))
		local _, missing = P.Shopping(guide, ctx)
		local bits = {}
		if st.train and st.step ~= st.train then
			bits[#bits + 1] = UI.Color({ 1, 0.5, 0.3 }, st.train.how
				and (st.train.how .. " Before " .. st.train.before .. ".")
				or ("Train " .. st.train.rank .. " before " .. st.train.before))
		end
		bits[#bits + 1] = missing > 0 and ("%d reagents still to get"):format(missing) or UI.Color("green", "All reagents in hand")
		tracker.extra:SetText(table.concat(bits, "\n"))
	end
	tracker:SetHeight(48 + tracker.step:GetStringHeight() + tracker.extra:GetStringHeight())
end

ns.On("CB_READY", function()
	tracker = build()
	ns.tracker = tracker
	render()
end)
ns.On("CB_REFRESH", render)

function ns.ShowTracker()
	ns.char.trackerHidden = nil
	if not ns.ActiveGuide() then return ns.ShowGuidePicker() end
	render()
end

function ns.ToggleTracker()
	if not ns.ActiveGuide() then return ns.ShowGuidePicker() end
	ns.char.trackerHidden = not ns.char.trackerHidden or nil
	if ns.char.trackerHidden then ns.Print("Tracker hidden. /craft brings it back.") end
	render()
end

-- The guide picker is the Craftbound window now.
function ns.ShowGuidePicker()
	ns.Window.Show()
end
