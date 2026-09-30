--[[
	SettingsController (ModuleScript)
	Location: StarterPlayer.StarterPlayerScripts.Controllers.SettingsController
	Applies saved settings (quality, volumes, camera shake, damage numbers).
	"Auto" quality = Low on phones/tablets, High on PC/console.
	Changes are sent to the server (ProfileAction "SetSetting") so they persist.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayerScripts = script.Parent.Parent

local QualityConfig = require(ReplicatedStorage.Modules.Config.QualityConfig)
local Net = require(ReplicatedStorage.Modules.Shared.Net)
local Signal = require(ReplicatedStorage.Modules.Shared.Signal)
local ClientRegistry = require(StarterPlayerScripts.ClientModules.ClientRegistry)
local Platform = require(StarterPlayerScripts.ClientModules.Platform)
local VFXLib = require(StarterPlayerScripts.ClientModules.VFXLib)
local SoundLib = require(StarterPlayerScripts.ClientModules.SoundLib)

local SettingsController = {}
SettingsController.Changed = Signal.new()
SettingsController.Settings = {
	Quality = "Auto",
	MusicVolume = 0.5,
	SfxVolume = 0.8,
	CameraShake = true,
	DamageNumbers = true,
	AutoDeleteCommon = false,
	AutoDeleteRare = false,
	SkipSpinAnimation = false,
}

function SettingsController:GetQualityName(): string
	local q = self.Settings.Quality
	if q == "Auto" then
		return Platform.IsMobileDevice() and "Low" or "High"
	end
	return q
end

function SettingsController:Apply()
	local s = self.Settings
	VFXLib.Quality = QualityConfig.Presets[self:GetQualityName()] or QualityConfig.Presets.Medium
	VFXLib.ShowDamageNumbers = s.DamageNumbers
	SoundLib.SetVolumes(s.SfxVolume, s.MusicVolume)
	self.Changed:Fire(s)
end

function SettingsController:Set(key: string, value: any)
	self.Settings[key] = value
	self:Apply()
	task.spawn(Net.Invoke, "ProfileAction", "SetSetting", key, value)
end

function SettingsController:Init()
	local data = ClientRegistry.Get("DataController")
	data.Changed:Connect(function(key, value)
		if key == "Settings" and type(value) == "table" then
			for k, v in pairs(value) do
				self.Settings[k] = v
			end
			self:Apply()
		end
	end)
	self:Apply()
end

return SettingsController
