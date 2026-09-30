--[[
	Settings tab (ModuleScript)
	Location: StarterPlayer.StarterPlayerScripts.UI.Tabs.Settings
	Quality (Auto/Low/Medium/High), music + sfx volume, camera shake, damage numbers,
	auto-delete spins, skip spin animation. Saved on the server with the player's data.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayerScripts = script.Parent.Parent.Parent

local QualityConfig = require(ReplicatedStorage.Modules.Config.QualityConfig)
local InputConfig = require(ReplicatedStorage.Modules.Config.InputConfig)
local ClientRegistry = require(StarterPlayerScripts.ClientModules.ClientRegistry)
local UIKit = require(StarterPlayerScripts.ClientModules.UIKit)

local SettingsTab = {}
SettingsTab.__index = SettingsTab

local T = UIKit.Theme

function SettingsTab.new(frame: Frame)
	local self = setmetatable({ Frame = frame, Built = false }, SettingsTab)
	return self
end

function SettingsTab:Refresh()
	-- Built once (rebuilding while dragging a slider would reset it).
	if self.Built then
		return
	end
	self.Built = true
	UIKit.Clear(self.Frame)
	local settingsController = ClientRegistry.Get("SettingsController")
	local s = settingsController.Settings
	local left = UIKit.Panel(self.Frame, { Size = UDim2.new(0.5, -6, 1, 0) })
	UIKit.Padding(left, 14)
	UIKit.List(left, nil, 8)
	UIKit.Label(left, "GRAPHICS & AUDIO", { TextSize = 16, Font = T.FontBlack, TextColor3 = T.Accent })
	local qualityButton
	qualityButton = UIKit.Button(left, "Quality: " .. s.Quality, { Size = UDim2.new(1, 0, 0, 38) }, function()
		local index = table.find(QualityConfig.Options, s.Quality) or 1
		local nextQuality = QualityConfig.Options[index % #QualityConfig.Options + 1]
		settingsController:Set("Quality", nextQuality)
		qualityButton.Text = "Quality: " .. nextQuality
	end)
	UIKit.Label(left, "Auto = Low on phones/tablets, High on PC/console.", { TextSize = 12, Font = T.Font, TextColor3 = T.SubText })
	UIKit.Slider(left, "Music Volume", s.MusicVolume, function(v)
		settingsController:Set("MusicVolume", v)
	end)
	UIKit.Slider(left, "Effects Volume", s.SfxVolume, function(v)
		settingsController:Set("SfxVolume", v)
	end)
	UIKit.Toggle(left, "Camera Shake", s.CameraShake, function(v)
		settingsController:Set("CameraShake", v)
	end)
	UIKit.Toggle(left, "Damage Numbers", s.DamageNumbers, function(v)
		settingsController:Set("DamageNumbers", v)
	end)
	local right = UIKit.Panel(self.Frame, { Position = UDim2.new(0.5, 6, 0, 0), Size = UDim2.new(0.5, -6, 1, 0) })
	UIKit.Padding(right, 14)
	UIKit.List(right, nil, 8)
	UIKit.Label(right, "SPINS", { TextSize = 16, Font = T.FontBlack, TextColor3 = T.Accent })
	UIKit.Toggle(right, "Auto-convert Common powers to Gold", s.AutoDeleteCommon, function(v)
		settingsController:Set("AutoDeleteCommon", v)
	end)
	UIKit.Toggle(right, "Auto-convert Rare powers to Gold", s.AutoDeleteRare, function(v)
		settingsController:Set("AutoDeleteRare", v)
	end)
	UIKit.Toggle(right, "Skip spin animation", s.SkipSpinAnimation, function(v)
		settingsController:Set("SkipSpinAnimation", v)
	end)
	UIKit.Label(right, "CONTROLS", { TextSize = 16, Font = T.FontBlack, TextColor3 = T.Accent })
	local lines = {}
	for _, action in ipairs({
		"M1",
		"Heavy",
		"Block",
		"Dash",
		"Sprint",
		"Skill1",
		"Skill4",
		"WeaponSkill1",
		"Transform",
		"LockOn",
		"Flight",
		"Menu",
		"Map",
	}) do
		table.insert(
			lines,
			string.format(
				"%s: %s / %s",
				InputConfig.Actions[action].Label,
				InputConfig.KeyboardLabel(action),
				InputConfig.GamepadLabel(action)
			)
		)
	end
	UIKit.Label(
		right,
		table.concat(lines, "\n"),
		{ TextSize = 12, Font = T.Font, Size = UDim2.new(1, 0, 0, 220), TextYAlignment = Enum.TextYAlignment.Top }
	)
end

return SettingsTab
