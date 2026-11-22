-- luacheck config: run "luacheck ." from this folder (Lua 5.1, like the WoW client).
-- The real API list is wowbench's (wowbench check .); this one only lists what Craftbound uses.
std = "lua51"
max_line_length = false
ignore = { "212", "432" }
exclude_files = { "tests/", "tools/", "docs/" }
globals = {
	"CraftboundDB", "CraftboundCharDB", "SLASH_CRAFTBOUND1", "SLASH_CRAFTBOUND2", "SlashCmdList",
	"BINDING_HEADER_CRAFTBOUND", "BINDING_NAME_CRAFTBOUND_CRAFT", "BINDING_NAME_CRAFTBOUND_BUY",
	"Craftbound_CraftNext", "Craftbound_BuyNext",
}
read_globals = {
	"ATTACHMENTS_MAX_RECEIVE", "AddonCompartmentFrame", "GetCursorPosition", "Minimap", "AuctionHouseFrame", "BuyMerchantItem", "GetInboxItem", "GetInboxNumItems", "C_AuctionHouse", "C_Item", "C_MerchantFrame", "C_Timer",
	"C_TradeSkillUI", "CreateFrame", "Enum", "GameTooltip", "GetMerchantItemID", "GetMerchantItemMaxStack",
	"GetMerchantNumItems", "GetMoney", "GetProfessionInfo", "GetProfessions", "GetTime", "InCombatLockdown",
	"IsShiftKeyDown", "ItemLocation", "MerchantFrame", "ProfessionsFrame", "StaticPopup_Hide", "UIParent",
	"UISpecialFrames", "UnitFactionGroup", "UnitLevel", "UnitName", "Screenshot", "StaticPopup_Show", "GetNumTrainerServices", "GetTrainerServiceInfo", "GetTrainerServiceCost", "BuyTrainerService", "IsTradeskillTrainer", "GetTrainerServiceSkillLine", "GetTrainerServiceTypeFilter", "PlaySound", "SOUNDKIT", "date", "geterrorhandler", "time", "tinsert",
}
