--[[
	VFXController (ModuleScript)
	Location: StarterPlayer.StarterPlayerScripts.Controllers.VFXController
	Receives "FX" events from the server and dispatches them:
	- world effects -> VFXLib (distance culled by quality setting)
	- local feedback (hitstop, hurt flash, cinematic, cooldowns, banners) -> controllers / HUD
	- animations / sounds / swings for OTHER characters
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayerScripts = script.Parent.Parent

local Net = require(ReplicatedStorage.Modules.Shared.Net)
local ClientRegistry = require(StarterPlayerScripts.ClientModules.ClientRegistry)
local VFXLib = require(StarterPlayerScripts.ClientModules.VFXLib)
local AnimationLib = require(StarterPlayerScripts.ClientModules.AnimationLib)
local SoundLib = require(StarterPlayerScripts.ClientModules.SoundLib)

local VFXController = {}

local player = Players.LocalPlayer

-- Effects that must always run (not distance culled)
local ALWAYS = {
	ProjectileEnd = true,
	Aura = true,
	Transform = true,
	Domain = true,
	TimeStop = true,
	ScreenFlash = true,
	ImpactFrame = true,
	CameraShake = true,
}

local function positionOf(params): Vector3?
	if params.Position then
		return params.Position
	end
	if params.CFrame then
		return params.CFrame.Position
	end
	if params.From then
		return params.From
	end
	if params.Origin then
		return params.Origin
	end
	local model = params.Model
	local root = model and model:FindFirstChild("HumanoidRootPart")
	return root and root.Position or nil
end

local function isOwnedByOtherPlayer(model: Model?): boolean
	if not model then
		return false
	end
	local owner = Players:GetPlayerFromCharacter(model)
	return owner ~= nil and owner ~= player
end

local Local = {}

function Local.Hitstop(p)
	ClientRegistry.Get("CombatController"):Hitstop(p.Duration or 0.05, p.Shake)
end

function Local.Hurt(p)
	local ratio = (p.Amount or 0) / math.max(1, p.MaxHealth or 100)
	VFXLib.ScreenFlashLocal(Color3.fromRGB(200, 0, 20), 0.35, math.clamp(0.85 - ratio * 3, 0.45, 0.85))
	ClientRegistry.Get("CameraController"):Shake(math.clamp(ratio * 4, 0.1, 0.6), 0.15)
end

function Local.Cinematic(p)
	ClientRegistry.Get("CameraController"):Cinematic(p.Duration or 1, p.Style, p.Color)
end

function Local.SkillCooldown(p)
	ClientRegistry.Get("AbilityController"):SetCooldown(p.Key, p.Duration)
end

function Local.QuestComplete(p)
	ClientRegistry.Get("HUD"):Banner("QUEST COMPLETE", p.Name, Color3.fromRGB(120, 255, 150))
	SoundLib.Play("QuestComplete")
end

function Local.RegionDiscovered(p)
	ClientRegistry.Get("HUD"):Banner("NEW REGION", p.Name, Color3.fromRGB(150, 200, 255))
end

function Local.SecretFound(p)
	ClientRegistry.Get("HUD"):Banner("SECRET FOUND", p.Name, Color3.fromRGB(20, 255, 200))
end

function Local.Achievement(p)
	ClientRegistry.Get("HUD"):Banner("ACHIEVEMENT", p.Name, Color3.fromRGB(255, 205, 80))
end

function Local.CraftSuccess()
	SoundLib.Play("QuestComplete")
end

local function onFX(effect: string, params)
	params = params or {}
	-- Local-only feedback
	local localHandler = Local[effect]
	if localHandler then
		local ok, err = pcall(localHandler, params)
		if not ok then
			warn("[VFXController] " .. effect .. ": " .. tostring(err))
		end
		return
	end
	if effect == "Anim" then
		-- Real animations on player characters replicate from their owner; procedural
		-- fallback poses do not, so every client plays those locally.
		if not (isOwnedByOtherPlayer(params.Model) and AnimationLib.HasAsset(params.Name)) then
			AnimationLib.Play(params.Model, params.Name, params.Speed)
		end
		return
	elseif effect == "Sound" then
		SoundLib.Play(params.Name, params.Position)
		return
	elseif effect == "Swing" then
		local model = params.Model
		if model and model ~= player.Character then
			local family = (params.Class == "Fist" or params.Class == nil) and "Fist" or "Blade"
			local animName = params.Heavy and "Heavy" or (family .. "_M1_" .. math.clamp(params.Combo or 1, 1, 4))
			if not (isOwnedByOtherPlayer(model) and AnimationLib.HasAsset(animName)) then
				AnimationLib.Play(model, animName)
			end
			VFXLib.WeaponTrail(model, params.Color, 0.2)
		end
		return
	elseif effect == "DashFX" and params.Model == player.Character then
		return -- we already played it locally
	elseif effect == "LevelUp" then
		SoundLib.Play("LevelUp", positionOf(params))
	elseif effect == "RareDrop" then
		SoundLib.Play("RareDrop", positionOf(params))
	elseif effect == "PerfectBlock" then
		SoundLib.Play("PerfectBlock", positionOf(params))
	elseif effect == "BossRoar" then
		SoundLib.Play("BossRoar", positionOf(params))
	elseif effect == "Transform" and params.Sound then
		SoundLib.Play(params.Sound, positionOf(params))
	elseif effect == "HitSpark" then
		SoundLib.Play(params.Heavy and "HitHeavy" or (params.Blocked and "Block" or "Hit"), params.Position, 0.5)
	end
	if not ALWAYS[effect] and not VFXLib.WithinDistance(positionOf(params)) then
		return
	end
	VFXLib.Play(effect, params)
end

function VFXController:Init()
	Net.Event("FX").OnClientEvent:Connect(onFX)
	-- Persistent cosmetic auras (attribute "CosmeticAura" on characters)
	local function watch(character: Model)
		local function refresh()
			local color = character:GetAttribute("CosmeticAura")
			if typeof(color) == "Color3" and not character:GetAttribute("Transformed") then
				VFXLib.Play("Aura", { Model = character, Color = color, Duration = 9999 })
			elseif not character:GetAttribute("Transformed") and not character:GetAttribute("Enraged") then
				VFXLib.ClearAura(character)
			end
		end
		character:GetAttributeChangedSignal("CosmeticAura"):Connect(refresh)
		character:GetAttributeChangedSignal("Enraged"):Connect(function()
			if not character:GetAttribute("Enraged") then
				VFXLib.ClearAura(character)
			end
		end)
		task.delay(1, refresh)
	end
	local function hookPlayer(other: Player)
		if other.Character then
			watch(other.Character)
		end
		other.CharacterAdded:Connect(watch)
	end
	for _, other in ipairs(Players:GetPlayers()) do
		hookPlayer(other)
	end
	Players.PlayerAdded:Connect(hookPlayer)
end

return VFXController
