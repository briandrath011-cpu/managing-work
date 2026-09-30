--[[
	Character tab (ModuleScript)
	Location: StarterPlayer.StarterPlayerScripts.UI.Tabs.Character
	Build overview: Power, Weapon, Fighting Style, Trait, Transformation, Armor, Head,
	Accessories, Title + totals of all modifiers. Trait rolling and transformation choice.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayerScripts = script.Parent.Parent.Parent

local Modules = ReplicatedStorage.Modules
local PowerRegistry = require(Modules.Powers.PowerRegistry)
local ItemUtil = require(Modules.Items.ItemUtil)
local Traits = require(Modules.Progression.Traits)
local Titles = require(Modules.Progression.Titles)
local Transformations = require(Modules.Progression.Transformations)
local FightingStyles = require(Modules.Combat.FightingStyles)
local Modifiers = require(Modules.Combat.Modifiers)
local GameConfig = require(Modules.Config.GameConfig)
local Net = require(Modules.Shared.Net)
local ClientRegistry = require(StarterPlayerScripts.ClientModules.ClientRegistry)
local UIKit = require(StarterPlayerScripts.ClientModules.UIKit)

local CharacterTab = {}
CharacterTab.__index = CharacterTab

local T = UIKit.Theme

function CharacterTab.new(frame: Frame)
	local self = setmetatable({ Frame = frame }, CharacterTab)
	self.Build = UIKit.Panel(frame, { Size = UDim2.new(0.5, -6, 1, 0) })
	UIKit.Padding(self.Build, 12)
	self.Side = UIKit.Panel(frame, { Position = UDim2.new(0.5, 6, 0, 0), Size = UDim2.new(0.5, -6, 1, 0) })
	UIKit.Padding(self.Side, 12)
	return self
end

local function row(parent, label, value, color)
	local r = UIKit.New("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 24), Parent = parent })
	UIKit.Label(r, label, { Size = UDim2.new(0.4, 0, 1, 0), TextColor3 = T.SubText, TextSize = 14 })
	UIKit.Label(
		r,
		value,
		{ Position = UDim2.fromScale(0.4, 0), Size = UDim2.new(0.6, 0, 1, 0), TextColor3 = color or T.Text, TextSize = 14 }
	)
end

function CharacterTab:Refresh()
	local data = ClientRegistry.Get("DataController"):Get()
	if not data then
		return
	end
	UIKit.Clear(self.Build)
	local list = UIKit.New("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = self.Build })
	UIKit.List(list, nil, 4)
	UIKit.Label(list, "BUILD", { TextSize = 18, Font = T.FontBlack, TextColor3 = T.Accent })
	local modifierList = {}
	local owned = data.Powers.Owned[data.Powers.EquippedUid]
	local power = owned and PowerRegistry.Get(owned.Id)
	row(list, "Power", power and power.DisplayName or "-", power and UIKit.RarityColor(power.Rarity))
	if power then
		table.insert(modifierList, power.Passive.Modifiers)
	end
	local function slotItem(slot)
		local uid = data.Equipment[slot]
		local entry = uid ~= "" and data.Inventory[uid]
		local def = entry and ItemUtil.Get(entry.Id)
		if def then
			table.insert(modifierList, def.Modifiers)
			if def.Passive then
				table.insert(modifierList, def.Passive.Modifiers)
			end
		end
		return def
	end
	local weapon = slotItem("Weapon")
	row(list, "Weapon", weapon and weapon.DisplayName or "-", weapon and UIKit.RarityColor(weapon.Rarity))
	local style = FightingStyles[data.FightingStyle]
	row(list, "Fighting Style", style and style.DisplayName or "-")
	if style then
		table.insert(modifierList, style.Modifiers)
	end
	local trait = Traits.Get(data.Trait)
	row(list, "Trait", trait and trait.DisplayName or "None", trait and UIKit.RarityColor(trait.Rarity))
	if trait then
		table.insert(modifierList, trait.Modifiers)
	end
	local transformation = Transformations.Get(data.Transformations.Equipped)
	row(
		list,
		"Transformation",
		transformation and transformation.DisplayName or "-",
		transformation and UIKit.RarityColor(transformation.Rarity)
	)
	for _, slot in ipairs({ "Armor", "Head", "Accessory1", "Accessory2" }) do
		local def = slotItem(slot)
		row(list, slot, def and def.DisplayName or "-", def and UIKit.RarityColor(def.Rarity))
	end
	local title = Titles.Get(data.Titles.Equipped)
	row(list, "Title", title and title.DisplayName or "-", title and UIKit.RarityColor(title.Rarity))
	UIKit.Label(list, "TOTAL BONUSES", { TextSize = 15, Font = T.FontBlack, TextColor3 = T.Accent })
	local total = Modifiers.Aggregate(modifierList)
	local lines = Modifiers.Describe(total)
	UIKit.Label(
		list,
		#lines > 0 and table.concat(lines, "   ") or "None",
		{ TextSize = 12, Font = T.Font, TextColor3 = T.Good, Size = UDim2.new(1, 0, 0, 80) }
	)

	-- Traits + transformations
	UIKit.Clear(self.Side)
	local side = UIKit.New("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = self.Side })
	UIKit.List(side, nil, 6)
	UIKit.Label(side, "TRAIT", { TextSize = 18, Font = T.FontBlack, TextColor3 = T.Accent })
	UIKit.Label(
		side,
		trait and (trait.DisplayName .. " - " .. trait.Description) or "No trait yet.",
		{ TextSize = 13, Size = UDim2.new(1, 0, 0, 34), TextColor3 = trait and UIKit.RarityColor(trait.Rarity) or T.SubText }
	)
	UIKit.Label(side, "Trait Rolls: " .. data.TraitRolls, { TextSize = 13 })
	local buttons = UIKit.New("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 36), Parent = side })
	UIKit.List(buttons, Enum.FillDirection.Horizontal, 6)
	local function roll(withGems)
		local ok, result = Net.Invoke("TraitAction", "Roll", withGems)
		if ok then
			local def = Traits.Get(result.Trait)
			ClientRegistry.Get("HUD"):Banner("NEW TRAIT", def and def.DisplayName or result.Trait, UIKit.RarityColor(result.Rarity))
		elseif result then
			ClientRegistry.Get("HUD"):Toast(result, "Error")
		end
	end
	UIKit.Button(buttons, "Roll Trait", { Size = UDim2.fromOffset(140, 34), BackgroundColor3 = T.Accent }, function()
		roll(false)
	end)
	UIKit.Button(buttons, "Roll (" .. GameConfig.Traits.RollGemCost .. " Gems)", { Size = UDim2.fromOffset(160, 34) }, function()
		roll(true)
	end)
	UIKit.Label(side, "TRANSFORMATIONS", { TextSize = 18, Font = T.FontBlack, TextColor3 = T.Accent })
	UIKit.Label(
		side,
		"Fill the Awakening bar by fighting, then press " .. "G / LB+RS / AWAKEN.",
		{ TextSize = 12, Font = T.Font, TextColor3 = T.SubText, Size = UDim2.new(1, 0, 0, 30) }
	)
	local ids = {}
	for id in pairs(Transformations.List) do
		table.insert(ids, id)
	end
	table.sort(ids)
	for _, id in ipairs(ids) do
		local def = Transformations.List[id]
		local unlocked = data.Transformations.Unlocked[id] == true
		local active = data.Transformations.Equipped == id
		UIKit.Button(side, string.format("%s%s %s", active and "▶ " or "", def.DisplayName, unlocked and "" or "(locked)"), {
			Size = UDim2.new(1, 0, 0, 34),
			BackgroundColor3 = active and T.Accent or T.PanelLight,
			TextColor3 = unlocked and UIKit.RarityColor(def.Rarity) or T.SubText,
		}, function()
			if not unlocked then
				ClientRegistry.Get("HUD")
					:Toast(def.UnlockLevel and ("Unlocks at level " .. def.UnlockLevel) or "Unlock with a rare boss drop", "Error")
				return
			end
			local ok, err = Net.Invoke("ProfileAction", "EquipTransformation", id)
			if not ok and err then
				ClientRegistry.Get("HUD"):Toast(err, "Error")
			end
		end)
	end
end

return CharacterTab
