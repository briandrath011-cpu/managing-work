--[[
	Stats tab (ModuleScript)
	Location: StarterPlayer.StarterPlayerScripts.UI.Tabs.Stats
	Allocate stat points (+1 / +5 / +10), reset (gems), derived character values.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayerScripts = script.Parent.Parent.Parent

local GameConfig = require(ReplicatedStorage.Modules.Config.GameConfig)
local Progression = require(ReplicatedStorage.Modules.Config.Progression)
local Net = require(ReplicatedStorage.Modules.Shared.Net)
local ClientRegistry = require(StarterPlayerScripts.ClientModules.ClientRegistry)
local UIKit = require(StarterPlayerScripts.ClientModules.UIKit)

local StatsTab = {}
StatsTab.__index = StatsTab

local T = UIKit.Theme
local STAT_COLORS = {
	Strength = Color3.fromRGB(255, 110, 90),
	Defense = Color3.fromRGB(120, 200, 255),
	Energy = Color3.fromRGB(160, 120, 255),
	Weapon = Color3.fromRGB(255, 200, 90),
	Agility = Color3.fromRGB(110, 255, 160),
}

function StatsTab.new(frame: Frame)
	local self = setmetatable({ Frame = frame, Rows = {} }, StatsTab)
	self.PointsLabel = UIKit.Label(frame, "", { Size = UDim2.new(1, 0, 0, 30), TextSize = 22, Font = T.FontBlack, TextColor3 = T.Gold })
	local list = UIKit.New(
		"Frame",
		{ BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 40), Size = UDim2.new(0.62, 0, 1, -40), Parent = frame }
	)
	UIKit.List(list, nil, 8)
	for index, stat in ipairs(GameConfig.Stats) do
		local row = UIKit.Panel(list, { Size = UDim2.new(1, 0, 0, 70), LayoutOrder = index })
		UIKit.Label(
			row,
			stat,
			{ Position = UDim2.fromOffset(12, 6), Size = UDim2.fromOffset(160, 24), TextSize = 18, TextColor3 = STAT_COLORS[stat] }
		)
		UIKit.Label(
			row,
			GameConfig.StatDescriptions[stat],
			{ Position = UDim2.fromOffset(12, 32), Size = UDim2.new(1, -250, 0, 32), TextSize = 12, Font = T.Font, TextColor3 = T.SubText }
		)
		local value = UIKit.Label(row, "0", {
			Position = UDim2.new(1, -236, 0, 6),
			Size = UDim2.fromOffset(60, 24),
			TextSize = 20,
			Font = T.FontBlack,
			TextXAlignment = Enum.TextXAlignment.Right,
		})
		for i, amount in ipairs({ 1, 5, 10 }) do
			UIKit.Button(
				row,
				"+" .. amount,
				{ Position = UDim2.new(1, -170 + (i - 1) * 54, 0, 16), Size = UDim2.fromOffset(48, 36), BackgroundColor3 = T.PanelLight },
				function()
					local ok, err = Net.Invoke("StatAction", "Allocate", stat, amount)
					if not ok and err then
						ClientRegistry.Get("HUD"):Toast(err, "Error")
					end
				end
			)
		end
		self.Rows[stat] = value
	end
	local derived = UIKit.Panel(frame, { Position = UDim2.new(0.64, 0, 0, 40), Size = UDim2.new(0.36, 0, 1, -40) })
	UIKit.Padding(derived, 14)
	UIKit.List(derived, nil, 6)
	UIKit.Label(derived, "CHARACTER", { TextSize = 16, Font = T.FontBlack, TextColor3 = T.Accent })
	self.Derived = {}
	for _, key in ipairs({
		"Max Health",
		"Max Energy",
		"Energy Regen",
		"Move Speed",
		"Dash Cooldown",
		"Crit Chance",
		"Physical Scaling",
		"Power Scaling",
		"Weapon Scaling",
	}) do
		self.Derived[key] = UIKit.Label(derived, key, { TextSize = 14, Font = T.Font })
	end
	UIKit.Button(derived, "Reset Stats (100 Gems)", { Size = UDim2.new(1, 0, 0, 40), BackgroundColor3 = T.Bad }, function()
		local ok, err = Net.Invoke("StatAction", "Reset")
		if not ok and err then
			ClientRegistry.Get("HUD"):Toast(err, "Error")
		end
	end)
	return self
end

function StatsTab:Refresh()
	local data = ClientRegistry.Get("DataController"):Get()
	if not data then
		return
	end
	self.PointsLabel.Text = string.format("Stat Points: %d", data.StatPoints)
	for stat, label in pairs(self.Rows) do
		label.Text = tostring(data.Stats[stat])
	end
	local s = data.Stats
	local character = game:GetService("Players").LocalPlayer.Character
	local function set(key, text)
		self.Derived[key].Text = key .. ":  " .. text
	end
	set("Max Health", tostring(Progression.MaxHealth(data.Level, s.Defense)))
	set("Max Energy", tostring(character and character:GetAttribute("MaxEnergy") or Progression.MaxEnergy(s.Energy)))
	set("Energy Regen", string.format("%.1f /s", Progression.EnergyRegen(s.Energy)))
	set("Move Speed", string.format("%.1f", character and character:GetAttribute("BaseWalkSpeed") or GameConfig.Character.WalkSpeed))
	set("Dash Cooldown", string.format("%.2fs", Progression.DashCooldown(s.Agility)))
	set(
		"Crit Chance",
		string.format(
			"%.1f%%",
			math.min(GameConfig.Combat.MaxCritChance, GameConfig.Combat.BaseCritChance + s.Agility * GameConfig.Combat.CritPerAgility) * 100
		)
	)
	set("Physical Scaling", string.format("x%.2f", 1 + s.Strength * 0.011))
	set("Power Scaling", string.format("x%.2f", 1 + s.Energy * 0.011))
	set("Weapon Scaling", string.format("x%.2f", 1 + s.Weapon * 0.011))
end

return StatsTab
