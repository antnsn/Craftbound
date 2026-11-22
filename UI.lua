-- UI kit: the few widgets the panels share. Dark parchment look that sits next to Blizzard's
-- profession window and auction house without pretending to be part of them.
local _, ns = ...

local UI = {}
ns.UI = UI

UI.GOLD = { 0.88, 0.63, 0.25 }
UI.COLORS = {
	orange = { 1.00, 0.50, 0.25 },
	yellow = { 1.00, 1.00, 0.00 },
	green = { 0.25, 0.75, 0.25 },
	gray = { 0.50, 0.50, 0.50 },
}
-- C_TradeSkillUI relativeDifficulty: 0 optimal, 1 medium, 2 easy, 3 trivial
UI.DIFFICULTY = { [0] = "orange", [1] = "yellow", [2] = "green", [3] = "gray" }

local BACKDROP = {
	bgFile = "Interface\\Buttons\\WHITE8X8",
	edgeFile = "Interface\\Buttons\\WHITE8X8",
	edgeSize = 1,
}

function UI.Panel(name, parent, w, h)
	local f = CreateFrame("Frame", name, parent or UIParent, "BackdropTemplate")
	f:SetSize(w, h)
	f:SetBackdrop(BACKDROP)
	f:SetBackdropColor(0.06, 0.05, 0.04, 0.94)
	f:SetBackdropBorderColor(0.45, 0.33, 0.15, 1)
	f:SetFrameStrata("MEDIUM")
	f:EnableMouse(true)
	return f
end

function UI.Text(parent, size, color, justify)
	local t = parent:CreateFontString(nil, "OVERLAY", size == "big" and "GameFontNormalLarge"
		or size == "small" and "GameFontHighlightSmall" or "GameFontHighlight")
	if color then t:SetTextColor(color[1], color[2], color[3]) end
	t:SetJustifyH(justify or "LEFT")
	t:SetWordWrap(true)
	return t
end

function UI.Button(parent, label, w, h, onClick)
	local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
	b:SetSize(w or 100, h or 22)
	b:SetText(label)
	local fs = b:GetFontString()
	if fs then -- long labels are cut off inside the button, never drawn past its edges
		fs:SetWidth((w or 100) - 12)
		fs:SetWordWrap(false)
	end
	if onClick then b:SetScript("OnClick", onClick) end
	return b
end

-- A one-line text field. onChange(box, text) runs when the player types (not on SetText).
function UI.Edit(parent, w, numeric, onChange)
	local e = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
	e:SetSize(w, 20)
	e:SetAutoFocus(false)
	if numeric then
		e:SetNumeric(true)
		e:SetMaxLetters(4)
	end
	e:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
	e:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
	if onChange then
		e:SetScript("OnTextChanged", function(self, user)
			if user then onChange(self, self:GetText() or "") end
		end)
	end
	return e
end

-- A small map button: a click sets a waypoint to what the route needs next (Waypoint.lua).
function UI.WayButton(parent)
	local b = UI.IconButton(parent, 18, "Interface\\Icons\\INV_Misc_Map_01", function() ns.Waypoint() end)
	UI.Tooltip(b, function(tip)
		local plan = ns.WayPlan and ns.WayPlan()
		tip:AddLine("Waypoint")
		tip:AddLine(plan and ("To " .. plan.label .. ", the nearest on your side.") or "Pick a guide first.", 1, 1, 1, true)
		tip:AddLine("/craft way trainer, recipe or vendor for one of them.", 0.6, 0.8, 1, true)
	end)
	return b
end

-- The Craftbound logo left of a title font string (moves the title right to make room).
function UI.TitleLogo(f, title, size)
	size = size or 20
	local logo = f:CreateTexture(nil, "ARTWORK")
	logo:SetTexture(ns.MEDIA .. "Logo64")
	logo:SetSize(size, size)
	local point, rel, relPoint, x, y = title:GetPoint(1)
	logo:SetPoint(point or "TOPLEFT", rel or f, relPoint or "TOPLEFT", (x or 0) - 1, (y or 0) + 2)
	title:ClearAllPoints()
	title:SetPoint("LEFT", logo, "RIGHT", 3, 0)
	return logo
end

-- Small square button with an icon texture.
function UI.IconButton(parent, size, icon, onClick)
	local b = CreateFrame("Button", nil, parent)
	b:SetSize(size, size)
	b.icon = b:CreateTexture(nil, "ARTWORK")
	b.icon:SetAllPoints()
	b.icon:SetTexture(icon)
	b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
	if onClick then b:SetScript("OnClick", onClick) end
	return b
end

function UI.Bar(parent, w, h)
	local bar = CreateFrame("StatusBar", nil, parent, "BackdropTemplate")
	bar:SetSize(w, h)
	bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
	bar:SetStatusBarColor(UI.GOLD[1], UI.GOLD[2], UI.GOLD[3])
	bar:SetMinMaxValues(0, 1)
	bar:SetBackdrop(BACKDROP)
	bar:SetBackdropColor(0, 0, 0, 0.6)
	bar:SetBackdropBorderColor(0.3, 0.22, 0.1, 1)
	bar.text = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	bar.text:SetPoint("CENTER")
	return bar
end

function UI.Divider(parent, y)
	local t = parent:CreateTexture(nil, "ARTWORK")
	t:SetColorTexture(0.45, 0.33, 0.15, 0.6)
	t:SetHeight(1)
	t:SetPoint("TOPLEFT", 8, y)
	t:SetPoint("TOPRIGHT", -8, y)
	return t
end

function UI.Tooltip(widget, fn)
	widget:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		fn(GameTooltip, self)
		GameTooltip:Show()
	end)
	widget:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

-- "|cffRRGGBBtext|r" for a colour name or rgb table.
function UI.Color(c, text)
	if type(c) == "string" then c = UI.COLORS[c] end
	if not c then return text end
	return ("|cff%02x%02x%02x%s|r"):format(c[1] * 255, c[2] * 255, c[3] * 255, text)
end

-- A row pool: rows are created on demand and hidden when not used.
function UI.Pool(parent, make)
	local pool = { rows = {}, used = 0 }
	function pool:Get()
		self.used = self.used + 1
		local r = self.rows[self.used]
		if not r then
			r = make(parent, self.used)
			self.rows[self.used] = r
		end
		r:Show()
		return r
	end
	function pool:Reset()
		self.used = 0
	end
	function pool:Finish()
		for i = self.used + 1, #self.rows do self.rows[i]:Hide() end
	end
	return pool
end

-- Make a frame draggable and remember where it sat (in the given table).
function UI.Movable(f, store, key)
	f:SetMovable(true)
	f:SetClampedToScreen(true)
	f:RegisterForDrag("LeftButton")
	f:SetScript("OnDragStart", f.StartMoving)
	f:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
		local point, _, _, x, y = self:GetPoint()
		store()[key] = { point = point, x = x, y = y }
	end)
end
