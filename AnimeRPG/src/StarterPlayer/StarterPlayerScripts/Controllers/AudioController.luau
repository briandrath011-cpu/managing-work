--[[
	AudioController (ModuleScript)
	Location: StarterPlayer.StarterPlayerScripts.Controllers.AudioController
	Music that follows the situation: Menu -> Region music (changes when entering a region)
	-> Boss music (while a boss bar is shown) -> Dungeon / Raid music. Smooth crossfades.
	Ambient loops for rain/storm. Track ids live in Modules.Assets.AssetIds.Music.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local StarterPlayerScripts = script.Parent.Parent

local AssetIds = require(ReplicatedStorage.Modules.Assets.AssetIds)
local WorldConfig = require(ReplicatedStorage.Modules.World.WorldConfig)
local ClientRegistry = require(StarterPlayerScripts.ClientModules.ClientRegistry)
local SoundLib = require(StarterPlayerScripts.ClientModules.SoundLib)
local UIKit = require(StarterPlayerScripts.ClientModules.UIKit)

local AudioController = {}

local player = Players.LocalPlayer
local current: Sound? = nil
local currentName = ""
local overrides: { [string]: any } = {} -- layer -> track name (Boss / Instance / Menu)

local function crossfade(trackName: string)
	if trackName == currentName then
		return
	end
	currentName = trackName
	local old = current
	if old then
		local fade = TweenService:Create(old, TweenInfo.new(1.2), { Volume = 0 })
		fade:Play()
		fade.Completed:Once(function()
			old:Destroy()
		end)
	end
	current = nil
	local id = AssetIds.Music[trackName] or ""
	if id == "" then
		return
	end
	local sound = Instance.new("Sound")
	sound.Name = "Music_" .. trackName
	sound.SoundId = id
	sound.Looped = true
	sound.Volume = 0
	sound.SoundGroup = SoundLib.MusicGroup
	sound.Parent = SoundService
	sound:Play()
	TweenService:Create(sound, TweenInfo.new(1.5), { Volume = 0.6 }):Play()
	current = sound
end

function AudioController:SetOverride(layer: string, trackName: string?)
	overrides[layer] = trackName
	self:Refresh()
end

function AudioController:Refresh()
	if overrides.Boss then
		crossfade(overrides.Boss)
		return
	end
	if overrides.Instance then
		crossfade(overrides.Instance)
		return
	end
	if overrides.Menu then
		crossfade(overrides.Menu)
		return
	end
	local character = player.Character
	local regionId = character and character:GetAttribute("Region")
	local region = regionId and WorldConfig.GetRegion(regionId)
	crossfade((region and region.Music) or "Region_Greenwood")
end

function AudioController:Init()
	UIKit.ClickSound = function()
		SoundLib.Play("UIClick", nil, 0.3, 1.2)
	end
	local function hook(character: Model)
		character:GetAttributeChangedSignal("Region"):Connect(function()
			self:Refresh()
		end)
		character:GetAttributeChangedSignal("InInstance"):Connect(function()
			local kind = character:GetAttribute("InInstance")
			self:SetOverride("Instance", kind == "Raid" and "Raid" or (kind == "Dungeon" and "Dungeon" or nil))
		end)
		self:Refresh()
	end
	if player.Character then
		hook(player.Character)
	end
	player.CharacterAdded:Connect(hook)
	ClientRegistry.Get("SettingsController").Changed:Connect(function()
		self:Refresh()
	end)
end

return AudioController
