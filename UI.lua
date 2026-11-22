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
	if onClick then b:SetScript("OnClick", onClick) end
	return b
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
