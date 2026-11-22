-- Cap guard: at a rank's cap (75/75, 150/150, 225/225) crafting gives no skill. Craftbound's own
-- Craft button already stops there; this asks before Blizzard's Create and Create All buttons
-- craft too. A frame of ours lies over each button while you are at the cap (Blizzard's buttons
-- are never changed or hooked in a way that could taint them). The first click asks; "Craft
-- anyway" lets clicks through until the skill or the cap changes. Not at 300: crafting there is
-- for the items. /craft toggle cap turns it off.
local _, ns = ...

local POPUP = "CRAFTBOUND_AT_CAP"
local BUTTONS = { "CreateButton", "CreateAllButton" }

local guards = {}   -- [blizzard button] = our frame over it
local allowed       -- "profession:rank:max" the player said yes to

-- The open profession's skill when it stands at a rank's cap below 300: rank, max.
local function atCap()
	if not (ns.open and ns.db.settings.capGuard) then return nil end
	local s = ns.char.skills[ns.open.profession]
	if not (s and s.rank and s.max) then return nil end
	if s.rank >= s.max and s.max < 300 then return s.rank, s.max end
end

local function key()
	local rank, max = atCap()
	return rank and ("%s:%d:%d"):format(ns.open.profession, rank, max)
end

local function update()
	local k = key()
	for button, guard in pairs(guards) do
		local on = k ~= nil and k ~= allowed and button:IsShown() and (not button.IsEnabled or button:IsEnabled())
		guard:SetShown(on and true or false)
	end
end
ns.UpdateCapGuard = update

local dialog = {
	text = "%s",
	button1 = "Craft anyway",
	button2 = "Cancel",
	OnAccept = function()
		allowed = key()
		update()
	end,
	timeout = 0,
	whileDead = true,
	hideOnEscape = true,
	preferredIndex = 3,
}
ns.CapPopup = dialog
local dialogs = rawget(_G, "StaticPopupDialogs")
if dialogs then dialogs[POPUP] = dialog end

local function ask()
	local rank, max = atCap()
	if not rank then return update() end
	local text = ("You are at %d/%d in %s: crafting gives no skill-up until you train the next rank.\n\nCraft anyway? (Click Create again after this.)")
		:format(rank, max, ns.open.profession)
	if StaticPopup_Show then StaticPopup_Show(POPUP, text) end
end

local function guard(button)
	if guards[button] then return end
	local g = CreateFrame("Button", nil, button)
	g:SetAllPoints(button)
	g:SetFrameLevel((tonumber(button:GetFrameLevel()) or 1) + 10)
	g:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	g:SetScript("OnClick", ask)
	g:SetScript("OnEnter", function(self)
		local rank, max = atCap()
		GameTooltip:SetOwner(self, "ANCHOR_TOP")
		GameTooltip:AddLine("Craftbound: at the cap")
		GameTooltip:AddLine(rank and ("%d/%d: crafting gives no skill-up. Train the next rank, or click to craft anyway."):format(rank, max) or "", 1, 1, 1, true)
		GameTooltip:Show()
	end)
	g:SetScript("OnLeave", function() GameTooltip:Hide() end)
	g:Hide()
	guards[button] = g
	-- follow Blizzard's button: no guard over a hidden or disabled button
	button:HookScript("OnShow", update)
	button:HookScript("OnHide", update)
	if button.HasScript and button:HasScript("OnEnable") then
		button:HookScript("OnEnable", update)
		button:HookScript("OnDisable", update)
	end
end

local function attach()
	local page = ProfessionsFrame and ProfessionsFrame.CraftingPage
	if not page then return end
	for _, name in ipairs(BUTTONS) do
		local b = page[name]
		if type(b) == "table" and b.IsObjectType and b:IsObjectType("Button") == true then guard(b) end
	end
	update()
end

ns.On("TRADE_SKILL_SHOW", function() C_Timer.After(0.2, attach) end)
ns.On("CB_REFRESH", update)
