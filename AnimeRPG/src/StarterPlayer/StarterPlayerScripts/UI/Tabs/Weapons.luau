--[[
	Weapons tab (ModuleScript)
	Location: StarterPlayer.StarterPlayerScripts.UI.Tabs.Weapons
	Owned weapons with class stats + mastery (0 M1 / 20 Z / 50 X / 100 C), fighting styles.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayerScripts = script.Parent.Parent.Parent

local ItemUtil = require(ReplicatedStorage.Modules.Items.ItemUtil)
local WeaponClasses = require(ReplicatedStorage.Modules.Weapons.WeaponClasses)
local WeaponSkills = require(ReplicatedStorage.Modules.Weapons.WeaponSkills)
local FightingStyles = require(ReplicatedStorage.Modules.Combat.FightingStyles)
local Progression = require(ReplicatedStorage.Modules.Config.Progression)
local RarityConfig = require(ReplicatedStorage.Modules.Config.RarityConfig)
local Net = require(ReplicatedStorage.Modules.Shared.Net)
local ClientRegistry = require(StarterPlayerScripts.ClientModules.ClientRegistry)
local UIKit = require(StarterPlayerScripts.ClientModules.UIKit)

local WeaponsTab = {}
WeaponsTab.__index = WeaponsTab

local T = UIKit.Theme
local KEYS = { "Z", "X", "C" }

function WeaponsTab.new(frame: Frame)
	local self = setmetatable({ Frame = frame }, WeaponsTab)
	self.List = UIKit.Scroll(frame, { Size = UDim2.new(0.62, -6, 1, 0) })
	UIKit.List(self.List, nil, 8)
	self.Styles = UIKit.Panel(frame, { Position = UDim2.new(0.62, 6, 0, 0), Size = UDim2.new(0.38, -6, 1, 0) })
	UIKit.Padding(self.Styles, 12)
	return self
end

function WeaponsTab:Refresh()
	local data = ClientRegistry.Get("DataController"):Get()
	if not data then
		return
	end
	UIKit.Clear(self.List)
	local weapons = {}
	for uid, entry in pairs(data.Inventory) do
		local def = ItemUtil.Get(entry.Id)
		if def and def.Category == "Weapon" then
			table.insert(weapons, { Uid = uid, Def = def })
		end
	end
	table.sort(weapons, function(a, b)
		return (RarityConfig.Rank[a.Def.Rarity] or 0) > (RarityConfig.Rank[b.Def.Rarity] or 0)
	end)
	if #weapons == 0 then
		UIKit.Label(
			self.List,
			"No weapons yet. Defeat enemies and bosses, or buy one from a merchant.",
			{ Size = UDim2.new(1, 0, 0, 40), TextColor3 = T.SubText }
		)
	end
	for index, weapon in ipairs(weapons) do
		local def = weapon.Def
		local class = WeaponClasses.List[def.Class]
		local record = data.WeaponMastery[def.Id] or { Level = 0, Exp = 0 }
		local card = UIKit.Panel(self.List, { Size = UDim2.new(1, -8, 0, 150), LayoutOrder = index })
		local stroke = card:FindFirstChildOfClass("UIStroke")
		if stroke then
			stroke.Color = UIKit.RarityColor(def.Rarity)
		end
		local equipped = data.Equipment.Weapon == weapon.Uid
		UIKit.Label(card, def.DisplayName, {
			Position = UDim2.fromOffset(12, 6),
			Size = UDim2.new(1, -140, 0, 24),
			TextSize = 18,
			Font = T.FontBlack,
			TextColor3 = UIKit.RarityColor(def.Rarity),
		})
		UIKit.Label(
			card,
			string.format(
				"%s • %s • DMG %d • SPD %.2f • RNG %d",
				def.Rarity,
				class.DisplayName,
				def.Damage,
				class.AttackSpeed,
				class.Range
			),
			{ Position = UDim2.fromOffset(12, 30), Size = UDim2.new(1, -140, 0, 18), TextSize = 12, TextColor3 = T.SubText }
		)
		local need = Progression.MasteryExpToNext(record.Level)
		local _, setBar = UIKit.Bar(card, T.Gold, { Position = UDim2.fromOffset(12, 52), Size = UDim2.new(1, -24, 0, 14) })
		setBar(
			need == math.huge and 1 or record.Exp / need,
			need == math.huge and "MASTERY MAX" or string.format("Mastery %d", record.Level)
		)
		local skillIds = ItemUtil.GetWeaponSkills(def.Id)
		for slot = 1, 3 do
			local skill = WeaponSkills[skillIds[slot]]
			local required = WeaponClasses.MasteryUnlocks[slot]
			local unlocked = record.Level >= required
			UIKit.Label(
				card,
				string.format(
					"[%s] %s  %s",
					KEYS[slot],
					skill and skill.Name or "?",
					unlocked and "✔" or ("(Mastery " .. required .. ")")
				),
				{
					Position = UDim2.fromOffset(12, 70 + (slot - 1) * 18),
					Size = UDim2.new(1, -24, 0, 18),
					TextSize = 12,
					TextColor3 = unlocked and T.Text or T.SubText,
				}
			)
		end
		if def.Passive then
			UIKit.Label(
				card,
				"Passive: " .. def.Passive.Name .. " - " .. def.Passive.Description,
				{ Position = UDim2.fromOffset(12, 126), Size = UDim2.new(1, -24, 0, 18), TextSize = 11, TextColor3 = T.Gold }
			)
		end
		UIKit.Button(
			card,
			equipped and "Equipped" or "Equip",
			{ Position = UDim2.new(1, -124, 0, 8), Size = UDim2.fromOffset(112, 34), BackgroundColor3 = equipped and T.Good or T.Accent },
			function()
				local ok, err = Net.Invoke("InventoryAction", equipped and "Unequip" or "Equip", equipped and "Weapon" or weapon.Uid)
				if not ok and err then
					ClientRegistry.Get("HUD"):Toast(err, "Error")
				end
			end
		)
	end
	-- Fighting styles
	UIKit.Clear(self.Styles)
	local list = UIKit.New("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = self.Styles })
	UIKit.List(list, nil, 6)
	UIKit.Label(list, "FIGHTING STYLES", { TextSize = 16, Font = T.FontBlack, TextColor3 = T.Accent })
	UIKit.Label(
		list,
		"Used when no weapon is equipped (scales with Strength). Learn new styles from Master Kaito.",
		{ TextSize = 12, Font = T.Font, Size = UDim2.new(1, 0, 0, 34), TextColor3 = T.SubText }
	)
	for id, style in pairs(FightingStyles) do
		if data.FightingStyles[id] then
			local active = data.FightingStyle == id
			UIKit.Button(
				list,
				(active and "▶ " or "") .. style.DisplayName,
				{ Size = UDim2.new(1, 0, 0, 34), BackgroundColor3 = active and T.Accent or T.PanelLight },
				function()
					local ok, err = Net.Invoke("ShopAction", "EquipStyle", id)
					if not ok and err then
						ClientRegistry.Get("HUD"):Toast(err, "Error")
					end
				end
			)
		end
	end
end

return WeaponsTab
