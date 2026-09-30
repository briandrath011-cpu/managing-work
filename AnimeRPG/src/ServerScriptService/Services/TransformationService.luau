--[[
	TransformationService (ModuleScript)
	Location: ServerScriptService.Services.TransformationService

	PHASE 18 - Transformations
	The Awakening bar (0-100, character attribute "Awakening") charges by dealing damage,
	taking damage and landing combo hits (DamageService calls AddAwakening).
	When full, the player can transform (RemoteEvent "Transform"): aura, camera effect,
	stat modifiers (CharacterService includes them), faster cooldowns.
	Equip/Unlock via ProfileAction ("EquipTransformation", id).
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Modules = ReplicatedStorage.Modules
local GameConfig = require(Modules.Config.GameConfig)
local Transformations = require(Modules.Progression.Transformations)
local Net = require(Modules.Shared.Net)
local Registry = require(ServerScriptService.ServerModules.Registry)
local EntityRegistry = require(ServerScriptService.ServerModules.EntityRegistry)
local RateLimiter = require(ServerScriptService.ServerModules.RateLimiter)

local TransformationService = {}

local awakening: { [Player]: number } = {}
local active: { [Player]: { Id: string, Ends: number } } = {}
local limiter = RateLimiter.new(3, 1)

local function dataService()
	return Registry.Get("PlayerDataService")
end

function TransformationService:GetActiveDefinition(player: Player)
	local current = active[player]
	return current and Transformations.Get(current.Id) or nil
end

function TransformationService:AddAwakening(player: Player, amount: number)
	if active[player] or amount <= 0 then
		return
	end
	local entity = EntityRegistry.GetForPlayer(player)
	local gain = amount * (1 + (entity and entity.Modifiers.AwakeningGain or 0))
	local value = math.min(GameConfig.Transform.MaxAwakening, (awakening[player] or 0) + gain)
	awakening[player] = value
	local character = player.Character
	if character then
		character:SetAttribute("Awakening", math.floor(value))
	end
end

function TransformationService:Unlock(player: Player, id: string): (boolean, string?)
	local data = dataService():Get(player)
	local def = Transformations.Get(id)
	if not data or not def then
		return false, "Unknown transformation"
	end
	if data.Transformations.Unlocked[id] then
		return false, "Already unlocked"
	end
	data.Transformations.Unlocked[id] = true
	if data.Transformations.Equipped == "" then
		data.Transformations.Equipped = id
	end
	dataService():Replicate(player, "Transformations")
	Registry.Get("FXService")
		:Notify(player, "Unlock", "Transformation unlocked: " .. def.DisplayName .. "! Fill your Awakening bar and press G.")
	return true
end

function TransformationService:Equip(player: Player, id: string): (boolean, string?)
	local data = dataService():Get(player)
	if not data or not data.Transformations.Unlocked[id] then
		return false, "Not unlocked"
	end
	data.Transformations.Equipped = id
	dataService():Replicate(player, "Transformations")
	return true
end

local function endTransformation(player: Player)
	active[player] = nil
	local character = player.Character
	if character then
		character:SetAttribute("Transformed", false)
		character:SetAttribute("TransformId", nil)
		character:SetAttribute("Awakening", 0)
	end
	awakening[player] = 0
	Registry.Get("CharacterService"):Refresh(player)
end

function TransformationService:Transform(player: Player): (boolean, string?)
	local data = dataService():Get(player)
	local entity = EntityRegistry.GetForPlayer(player)
	if not data or not entity or not EntityRegistry.IsAlive(entity) then
		return false, "Can't transform"
	end
	if active[player] then
		return false, "Already transformed"
	end
	local def = Transformations.Get(data.Transformations.Equipped)
	if not def then
		return false, "No transformation equipped"
	end
	if (awakening[player] or 0) < GameConfig.Transform.MaxAwakening then
		return false, "Awakening bar not full"
	end
	local duration = def.Duration or GameConfig.Transform.Duration
	active[player] = { Id = def.Id, Ends = os.clock() + duration }
	local character = entity.Model
	character:SetAttribute("Transformed", true)
	character:SetAttribute("TransformId", def.Id)
	entity.State.IFramesUntil = os.clock() + 1.2
	entity.State.SuperArmorUntil = os.clock() + 1.5
	Registry.Get("CharacterService"):Refresh(player)
	local fx = Registry.Get("FXService")
	fx:Play(
		"Transform",
		{ Model = character, Color = def.AuraColor, Color2 = def.SecondaryColor, Duration = duration, Sound = def.Sound },
		entity.Root.Position
	)
	fx:PlayFor(player, "Cinematic", { Model = character, Duration = 1.4, Style = "Transform", Color = def.AuraColor })
	-- Transformation shockwave damages nearby enemies.
	local SkillContext = require(ServerScriptService.ServerModules.SkillContext)
	local ctx = SkillContext.new({
		Entity = entity,
		Skill = { Name = def.DisplayName, Damage = 40 + data.Level * 2 },
		Source = "Transform",
		SourceId = def.Id,
		Color = def.AuraColor,
		DamageType = "Power",
		Scaling = "Energy",
	})
	ctx:HitRadius(entity.Root.Position, 18, { Stun = 0.8, Knockback = 80, Up = 20, NoAwakening = true })

	task.delay(duration, function()
		local current = active[player]
		if current and current.Id == def.Id and os.clock() >= current.Ends - 0.05 then
			endTransformation(player)
		end
	end)
	return true
end

function TransformationService:Init()
	Net.Event("Transform").OnServerEvent:Connect(function(player)
		if not limiter:Check(player) then
			return
		end
		local ok, err = TransformationService:Transform(player)
		if not ok and err then
			Registry.Get("FXService"):Notify(player, "Error", err)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		awakening[player] = nil
		active[player] = nil
	end)
	-- Level-based unlocks (Awakening at level 25).
	dataService().LevelUp:Connect(function(player, level)
		for id, def in pairs(Transformations.List) do
			if def.UnlockLevel and level >= def.UnlockLevel then
				local data = dataService():Get(player)
				if data and not data.Transformations.Unlocked[id] then
					TransformationService:Unlock(player, id)
				end
			end
		end
	end)
end

function TransformationService:Start()
	Registry.Get("CharacterService").CharacterReady:Connect(function(player, character)
		active[player] = nil
		awakening[player] = 0
		character:SetAttribute("Awakening", 0)
		character:SetAttribute("Transformed", false)
		-- Catch up level unlocks for old saves.
		local data = dataService():Get(player)
		if data then
			for id, def in pairs(Transformations.List) do
				if def.UnlockLevel and data.Level >= def.UnlockLevel and not data.Transformations.Unlocked[id] then
					TransformationService:Unlock(player, id)
				end
			end
		end
	end)
end

return TransformationService
