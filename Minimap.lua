-- Minimap button: left-click shows or hides the tracker, right-click picks a guide, drag to move.
-- Also listed in the addon compartment.
--
-- When another addon has loaded LibDataBroker-1.1 and LibDBIcon-1.0 (most minimap collectors do),
-- the button is a broker launcher so those addons gather it like any other. Without them it is a
-- button of its own. Position: ns.db.minimapIcon (LibDBIcon's table: minimapPos in degrees, hide);
-- ns.db.settings.minimap shows or hides it.
local _, ns = ...

local ICON = ns.MEDIA .. "Icon64"
local NAME = "Craftbound"

local btn, dbi

local function onClick(_, button)
	if button == "RightButton" then
		ns.ShowGuidePicker()
	else
		ns.ToggleTracker()
	end
end
ns.MinimapClick = onClick

local function tooltip(tt)
	tt:AddLine(ns.title)
	local guide = ns.ActiveGuide()
	if guide then
		local st, ctx = ns.Status(guide)
		tt:AddLine(("%s %d/%d"):format(guide.profession, ctx.skill, guide.to), 1, 0.82, 0)
		tt:AddLine(ns.Planner.Describe(st.step, st.left), 1, 1, 1, true)
	else
		tt:AddLine("No guide picked yet.", 1, 1, 1)
	end
	tt:AddLine("Left-click: show or hide the tracker", 0.6, 0.8, 1)
	tt:AddLine("Right-click: pick a guide", 0.6, 0.8, 1)
	tt:AddLine("Drag: move", 0.6, 0.6, 0.6)
end

local function iconDB()
	local d = ns.db.minimapIcon
	if type(d) ~= "table" then
		d = { minimapPos = 200 }
		ns.db.minimapIcon = d
	end
	d.hide = not ns.db.settings.minimap
	return d
end

function ns.UpdateMinimap()
	if dbi then
		iconDB()
		if ns.db.settings.minimap then dbi:Show(NAME) else dbi:Hide(NAME) end
	elseif btn then
		btn:SetShown(ns.db.settings.minimap and true or false)
	end
end

local function initBroker(LDB, DBI)
	local obj = LDB:NewDataObject(NAME, {
		type = "launcher", label = NAME, icon = ICON,
		OnClick = onClick, OnTooltipShow = tooltip,
	})
	if not obj then return false end
	DBI:Register(NAME, obj, iconDB())
	dbi = DBI
	return true
end

-- without LibDBIcon: a button of our own, placed by an angle around the minimap
local function place()
	local angle = math.rad(iconDB().minimapPos or 200)
	local r = (Minimap:GetWidth() / 2) + 5
	btn:ClearAllPoints()
	btn:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * r, math.sin(angle) * r)
end

local function onDragUpdate()
	local mx, my = Minimap:GetCenter()
	local scale = Minimap:GetEffectiveScale()
	local cx, cy = GetCursorPosition()
	cx, cy = cx / scale, cy / scale
	iconDB().minimapPos = math.deg(math.atan2(cy - my, cx - mx)) % 360
	place()
end

local function initButton()
	btn = CreateFrame("Button", "CraftboundMinimapButton", Minimap)
	btn:SetSize(31, 31)
	btn:SetFrameStrata("MEDIUM")
	btn:SetFrameLevel(8)
	btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	btn:RegisterForDrag("LeftButton")
	btn:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
	local bg = btn:CreateTexture(nil, "BACKGROUND")
	bg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
	bg:SetSize(20, 20)
	bg:SetPoint("TOPLEFT", 7, -5)
	local icon = btn:CreateTexture(nil, "ARTWORK")
	icon:SetTexture(ICON)
	icon:SetSize(18, 18)
	icon:SetPoint("TOPLEFT", 7, -6)
	icon:SetTexCoord(0.04, 0.96, 0.04, 0.96)
	btn.icon = icon
	local border = btn:CreateTexture(nil, "OVERLAY")
	border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
	border:SetSize(53, 53)
	border:SetPoint("TOPLEFT")
	btn:SetScript("OnClick", onClick)
	btn:SetScript("OnMouseDown", function() icon:SetPoint("TOPLEFT", 8, -7) end)
	btn:SetScript("OnMouseUp", function() icon:SetPoint("TOPLEFT", 7, -6) end)
	btn:SetScript("OnDragStart", function(self)
		self:LockHighlight()
		self:SetScript("OnUpdate", onDragUpdate)
	end)
	btn:SetScript("OnDragStop", function(self)
		self:SetScript("OnUpdate", nil)
		self:UnlockHighlight()
		icon:SetPoint("TOPLEFT", 7, -6)
	end)
	btn:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_LEFT")
		tooltip(GameTooltip)
		GameTooltip:Show()
	end)
	btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
	place()
end

ns.On("CB_READY", function()
	if not Minimap then return end
	-- LibStub is not ours: only there when another addon embeds it
	local stub = rawget(_G, "LibStub")
	local LDB = stub and stub("LibDataBroker-1.1", true)
	local DBI = stub and stub("LibDBIcon-1.0", true)
	local ok, done = false, false
	if LDB and DBI then ok, done = pcall(initBroker, LDB, DBI) end
	if not (ok and done) then
		dbi = nil
		initButton()
	end
	ns.UpdateMinimap()
	if AddonCompartmentFrame and AddonCompartmentFrame.RegisterAddon then
		pcall(AddonCompartmentFrame.RegisterAddon, AddonCompartmentFrame, {
			text = NAME, icon = ICON, notCheckable = true,
			func = function(_, input, _, _, button)
				local b = (type(input) == "table" and input.buttonName) or button
				onClick(nil, b)
			end,
		})
	end
end)
