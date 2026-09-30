--[[
	BossService (ModuleScript)
	Location: ServerScriptService.Services.BossService

	PHASE 13 - Boss System
	- World bosses from WorldConfig.Bosses (respawn timers, night-only secret boss)
	- Intro cinematic when players enter the arena (boss invulnerable during intro)
	- Boss health bar for everyone inside the arena (BossUI remote, throttled)
	- Phases / enrage / ultimate are handled by AIBrain (see BossCatalog)
	- SpawnBoss() is also used by dungeons, raids and world events
	Remote: BossUI (RemoteEvent) ("Intro" | "Update" | "Hide" | "Defeated", payload)
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Modules = ReplicatedStorage.Modules
local BossCatalog = require(Modules.Bosses.BossCatalog)
local WorldConfig = require(Modules.World.WorldConfig)
local Signal = require(Modules.Shared.Signal)
local Net = require(Modules.Shared.Net)
local Registry = require(ServerScriptService.ServerModules.Registry)
local EntityRegistry = require(ServerScriptService.ServerModules.EntityRegistry)

local BossService = {}
BossService.BossDefeated = Signal.new() -- (bossId, entity, tag)

type ActiveBoss = {
	Id: string,
	Entity: any,
	Brain: any,
	Def: any,
	Arena: Vector3,
	Radius: number,
	IntroDone: boolean,
	Viewers: { [Player]: boolean },
	Tag: string?,
}

local activeBosses: { [Model]: ActiveBoss } = {}
local bossUI: RemoteEvent

local function sendPhase(boss: ActiveBoss, phaseIndex: number, phase)
	for player in pairs(boss.Viewers) do
		bossUI:FireClient(player, "Phase", { Model = boss.Entity.Model, Phase = phaseIndex, Enraged = phase.Enrage == true })
	end
	if phase.Enrage then
		Registry.Get("FXService"):Notify(nil, "Boss", string.format("⚠ %s is ENRAGED!", boss.Def.DisplayName))
	end
end

--[[
	options: Level, Tag, Folder, HealthScale, DamageScale, OnDeath, Arena (Vector3), Radius
]]
function BossService:SpawnBoss(bossId: string, position: Vector3, options: { [string]: any }?)
	local opts = options or {}
	local def = BossCatalog[bossId]
	if not def then
		warn("[BossService] Unknown boss " .. tostring(bossId))
		return nil
	end
	local record: ActiveBoss
	local entity, brain = Registry.Get("EnemyService"):Spawn(bossId, {
		Position = position,
		Level = opts.Level,
		Tag = opts.Tag,
		Folder = opts.Folder,
		HealthScale = opts.HealthScale,
		DamageScale = opts.DamageScale,
		LeashRange = (opts.Radius or def.ArenaRadius or 90) * 1.5,
		OnPhaseChange = function(_, phaseIndex, phase)
			if record then
				sendPhase(record, phaseIndex, phase)
			end
		end,
		OnDeath = function(deadEntity)
			local current = activeBosses[deadEntity.Model]
			activeBosses[deadEntity.Model] = nil
			if current then
				for player in pairs(current.Viewers) do
					bossUI:FireClient(player, "Defeated", { Name = def.DisplayName, Model = deadEntity.Model })
				end
			end
			Registry.Get("FXService"):Notify(nil, "Boss", string.format("%s has been defeated!", def.DisplayName))
			BossService.BossDefeated:Fire(bossId, deadEntity, opts.Tag)
			if opts.OnDeath then
				task.spawn(opts.OnDeath, deadEntity)
			end
		end,
	})
	if not entity then
		return nil
	end
	record = {
		Id = bossId,
		Entity = entity,
		Brain = brain,
		Def = entity.Definition,
		Arena = opts.Arena or position,
		Radius = opts.Radius or def.ArenaRadius or 90,
		IntroDone = false,
		Viewers = {},
		Tag = opts.Tag,
	}
	activeBosses[entity.Model] = record
	-- Invulnerable and idle until someone triggers the intro.
	entity.State.IFramesUntil = math.huge
	entity.State.ActionLockUntil = math.huge
	return entity, brain
end

function BossService:GetActive(): { [Model]: ActiveBoss }
	return activeBosses
end

local function playIntro(boss: ActiveBoss, viewers: { Player })
	boss.IntroDone = true
	local entity = boss.Entity
	entity.State.IFramesUntil = os.clock() + 2.8
	entity.State.ActionLockUntil = os.clock() + 2.8
	for _, player in ipairs(viewers) do
		bossUI:FireClient(player, "Intro", {
			Model = entity.Model,
			Name = boss.Def.DisplayName,
			Level = entity.Level,
			Color = boss.Def.AttackColor,
			Music = boss.Def.Music,
		})
	end
	Registry.Get("FXService"):Play("BossRoar", { Model = entity.Model, Color = boss.Def.AttackColor }, entity.Root.Position)
end

-- World boss spawners (respawn after death, night-only bosses).
local function runWorldBoss(entry)
	local def = BossCatalog[entry.Boss]
	task.spawn(function()
		while true do
			if def.NightOnly then
				while workspace:GetAttribute("TimePhase") ~= "Night" do
					task.wait(5)
				end
			end
			local done = false
			local entity = BossService:SpawnBoss(entry.Boss, entry.Position, {
				OnDeath = function()
					done = true
				end,
			})
			if def.NightOnly then
				Registry.Get("FXService"):Notify(nil, "Event", "🌙 Something stirs in the old graveyard...")
			end
			while not done do
				task.wait(3)
				if def.NightOnly and workspace:GetAttribute("TimePhase") ~= "Night" and entity and entity.Model.Parent then
					-- Vanish at dawn if nobody is fighting it.
					if os.clock() - entity.State.LastCombatTime > 20 then
						activeBosses[entity.Model] = nil
						entity.Model:Destroy()
						done = true
					end
				end
				if entity and not entity.Model.Parent then
					done = true
				end
			end
			task.wait(def.RespawnTime or 180)
		end
	end)
end

function BossService:Init()
	bossUI = Net.Event("BossUI")
end

function BossService:Start()
	Registry.Get("WorldBuilder"):WaitUntilBuilt()
	for _, entry in ipairs(WorldConfig.Bosses) do
		runWorldBoss(entry)
	end

	-- Arena / UI loop (4 Hz)
	while true do
		task.wait(0.25)
		for model, boss in pairs(activeBosses) do
			if not model.Parent or not EntityRegistry.IsAlive(boss.Entity) then
				activeBosses[model] = nil
				continue
			end
			local humanoid = boss.Entity.Humanoid
			local inside = {}
			for _, player in ipairs(Players:GetPlayers()) do
				local character = player.Character
				local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
				if root and (root.Position - boss.Arena).Magnitude <= boss.Radius then
					table.insert(inside, player)
				end
			end
			if not boss.IntroDone then
				local close = {}
				for _, player in ipairs(inside) do
					local root = (player.Character :: Model):FindFirstChild("HumanoidRootPart") :: BasePart
					if (root.Position - boss.Arena).Magnitude <= boss.Radius * 0.6 then
						table.insert(close, player)
					end
				end
				if #close > 0 then
					playIntro(boss, inside)
				end
			end
			local insideSet = {}
			for _, player in ipairs(inside) do
				insideSet[player] = true
				boss.Viewers[player] = true
				bossUI:FireClient(player, "Update", {
					Model = model,
					Name = boss.Def.DisplayName,
					Level = boss.Entity.Level,
					Health = humanoid.Health,
					MaxHealth = humanoid.MaxHealth,
					Phase = boss.Brain and boss.Brain.Phase or 1,
					Enraged = boss.Brain and boss.Brain.Enraged or false,
					Music = boss.Def.Music,
				})
			end
			for player in pairs(boss.Viewers) do
				if not insideSet[player] then
					boss.Viewers[player] = nil
					if player.Parent then
						bossUI:FireClient(player, "Hide", { Model = model })
					end
				end
			end
			-- Reset out-of-combat bosses (no one inside): heal to full.
			if #inside == 0 and boss.IntroDone and os.clock() - boss.Entity.State.LastCombatTime > 15 then
				humanoid.Health = humanoid.MaxHealth
				boss.IntroDone = false
				boss.Entity.State.IFramesUntil = math.huge
				boss.Entity.State.ActionLockUntil = math.huge
				boss.Entity.DamageContrib = {}
				if boss.Brain then
					boss.Brain.Phase = 1
					boss.Brain.Enraged = false
					boss.Brain.Target = nil
					model:SetAttribute("Enraged", false)
					humanoid.WalkSpeed = boss.Brain.BaseWalkSpeed
					humanoid:MoveTo(boss.Arena)
				end
			end
		end
	end
end

return BossService
