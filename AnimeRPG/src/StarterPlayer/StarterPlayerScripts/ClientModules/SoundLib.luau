--[[
	SoundLib (ModuleScript)
	Location: StarterPlayer.StarterPlayerScripts.ClientModules.SoundLib
	Plays sounds by NAME (see Modules.Assets.AssetIds.Sounds). Empty ids are skipped.
	3D sounds are pooled on invisible parts; 2D sounds go into SoundService.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local Workspace = game:GetService("Workspace")

local AssetIds = require(ReplicatedStorage.Modules.Assets.AssetIds)

local SoundLib = {}
SoundLib.SfxVolume = 0.8

local sfxGroup = Instance.new("SoundGroup")
sfxGroup.Name = "SFX"
sfxGroup.Volume = 0.8
sfxGroup.Parent = SoundService

local musicGroup = Instance.new("SoundGroup")
musicGroup.Name = "Music"
musicGroup.Volume = 0.5
musicGroup.Parent = SoundService

SoundLib.SfxGroup = sfxGroup
SoundLib.MusicGroup = musicGroup

local emitterPool: { BasePart } = {}
local MAX_EMITTERS = 24
local active = 0

local function getEmitter(): BasePart
	local part = table.remove(emitterPool)
	if part then
		return part
	end
	local newPart = Instance.new("Part")
	newPart.Name = "SoundEmitter"
	newPart.Anchored = true
	newPart.CanCollide = false
	newPart.CanQuery = false
	newPart.CanTouch = false
	newPart.Transparency = 1
	newPart.Size = Vector3.new(0.2, 0.2, 0.2)
	newPart.Parent = Workspace:FindFirstChild("Effects") or Workspace
	return newPart
end

function SoundLib.GetId(name: string): string
	return AssetIds.Sounds[name] or ""
end

function SoundLib.SetVolumes(sfx: number, music: number)
	sfxGroup.Volume = sfx
	musicGroup.Volume = music
end

function SoundLib.Play(name: string, position: Vector3?, volume: number?, pitch: number?)
	local id = SoundLib.GetId(name)
	if id == "" or active >= MAX_EMITTERS then
		return nil
	end
	local sound = Instance.new("Sound")
	sound.SoundId = id
	sound.Volume = volume or 0.7
	sound.PlaybackSpeed = pitch or (0.95 + math.random() * 0.1)
	sound.SoundGroup = sfxGroup
	sound.RollOffMaxDistance = 200
	sound.RollOffMinDistance = 12
	local emitter: BasePart? = nil
	if position then
		emitter = getEmitter();
		(emitter :: BasePart).CFrame = CFrame.new(position)
		sound.Parent = emitter
	else
		sound.Parent = SoundService
	end
	active += 1
	sound:Play()
	local function cleanup()
		active -= 1
		sound:Destroy()
		if emitter then
			table.insert(emitterPool, emitter)
		end
	end
	sound.Ended:Once(cleanup)
	task.delay(8, function()
		if sound.Parent then
			cleanup()
		end
	end)
	return sound
end

return SoundLib
