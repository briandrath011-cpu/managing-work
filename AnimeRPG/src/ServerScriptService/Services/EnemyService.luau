--[[
	EnemyService (ModuleScript)
	Location: ServerScriptService.Services.EnemyService

	PHASE 11 - Enemies (+ summons + minions)
	- Region spawners from WorldConfig.EnemySpawns with respawn timers
	- One AI loop for every NPC (performance): inactive NPCs far from players are skipped
	- Kill rewards delegated to DropService, quest progress to QuestService
	Folders: Workspace.Enemies (hostile), Workspace.NPCs.Summons (allies)
]]
local Players = game:GetService("Players")
local PhysicsService = game:GetService("PhysicsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Modules = ReplicatedStorage.Modules
local GameConfig = require(Modules.Config.GameConfig)
local EnemyCatalog = require(Modules.Enemies.EnemyCatalog)
local BossCatalog = require(Modules.Bosses.BossCatalog)
local WorldConfig = require(Modules.World.WorldConfig)
local Signal = require(Modules.Shared.Signal)
local Registry = require(ServerScriptService.ServerModules.Registry)
local EntityRegistry = require(ServerScriptService.ServerModules.EntityRegistry)
local NPCRig = require(ServerScriptService.ServerModules.NPCRig)
local AIBrain = require(ServerScriptService.ServerModules.AIBrain)
local WeaponVisual = require(ServerScriptService.ServerModules.WeaponVisual)

local EnemyService = {}
EnemyService.EnemyDied = Signal.new() -- (entity, def, options)

local brains: { [Model]: any } = {}
local active: { [Model]: boolean } = {}
local summonsByOwner: { [Player]: { any } } = {}
local rng = Random.new()

local function getFolder(name: string, parent: Instance?): Folder
	local root = parent or workspace
	local folder = root:FindFirstChild(name)
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = name
		folder.Parent = root
	end
	return folder :: Folder
end

-- Health / damage formulas for NPCs (single place to balance).
function EnemyService:HealthFor(level: number, multiplier: number): number
	return math.floor((50 + level ^ 1.45 * 5) * multiplier)
end

function EnemyService:DamageFor(level: number, multiplier: number): number
	return (5 + level * 1.6) * multiplier
end

function EnemyService:DefenseFor(level: number): number
	return level * 0.5
end

local function resolveDef(defOrId)
	if type(defOrId) == "table" then
		return defOrId
	end
	return EnemyCatalog[defOrId] or BossCatalog[defOrId]
end

--[[
	options: Position (Vector3), Level (override), Home, Team ("Enemies"|"Allies"), Owner (Player),
	         Folder, NoRespawn, OnDeath(entity), HealthScale, DamageScale, NoRewards, Tag,
	         DisplayName, LeashRange
]]
function EnemyService:Spawn(defOrId, options): (any?, any?)
	local base = resolveDef(defOrId)
	if not base then
		warn("[EnemyService] Unknown enemy " .. tostring(defOrId))
		return nil, nil
	end
	local level = options.Level or base.Level
	if level <= 0 then
		level = 1
	end
	local def = table.clone(base)
	def.Level = level
	def.Damage = self:DamageFor(level, (base.DamageMultiplier or 1) * (options.DamageScale or 1))

	local colors = def.Colors or {}
	local model =
		NPCRig.Create({ Id = options.RigId or base.Id, Body = colors.Body, Accent = colors.Accent, Head = colors.Head or colors.Body })
	local humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart
	model.Name = options.DisplayName or def.DisplayName
	local scale = def.Scale or 1
	if scale ~= 1 then
		pcall(function()
			model:ScaleTo(scale)
		end)
	end
	local maxHealth = self:HealthFor(level, (def.HealthMultiplier or 1) * (options.HealthScale or 1))
	humanoid.MaxHealth = maxHealth
	humanoid.Health = maxHealth
	humanoid.WalkSpeed = def.WalkSpeed or 16
	humanoid.BreakJointsOnDeath = false
	NPCRig.Prepare(model)

	local team = options.Team or "Enemies"
	local folder = options.Folder
		or (team == "Allies" and getFolder("Summons", getFolder("NPCs")) or getFolder(def.IsBoss and "Bosses" or "Enemies"))
	local position = options.Position or Vector3.new(0, 5, 0)
	model:PivotTo(CFrame.new(position + Vector3.new(0, 3 * scale, 0)) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0))
	model.Parent = folder
	pcall(function()
		root:SetNetworkOwner(nil)
	end)

	if def.WeaponClass then
		local WeaponClasses = require(Modules.Weapons.WeaponClasses)
		local class = WeaponClasses.List[def.WeaponClass]
		if class then
			WeaponVisual.Attach(
				model,
				{ Id = def.Id .. "_Weapon", Color = colors.Accent, Accent = colors.Body, Glow = def.AttackColor },
				class
			)
		end
	end

	local nameColor = team == "Allies" and Color3.fromRGB(140, 200, 255)
		or (def.IsBoss and Color3.fromRGB(255, 90, 90) or Color3.fromRGB(255, 235, 200))
	NPCRig.AddOverhead(model, string.format("%s  [Lv. %d]", model.Name, level), nameColor, not def.IsBoss, scale)

	local entity = EntityRegistry.Register(model, {
		Team = team,
		Level = level,
		Defense = self:DefenseFor(level),
		Definition = def,
		Owner = options.Owner,
		Stats = { Strength = 0, Defense = 0, Energy = 0, Weapon = 0, Agility = level * 0.5 },
		Modifiers = {},
	})
	if not entity then
		model:Destroy()
		return nil, nil
	end
	model:SetAttribute("EnemyId", base.Id)
	model:SetAttribute("IsBoss", def.IsBoss == true)
	if options.Tag then
		model:SetAttribute("Tag", options.Tag)
	end

	local brain = AIBrain.new(entity, def, {
		Home = position,
		LeashRange = options.LeashRange,
		Owner = options.Owner,
		OnPhaseChange = options.OnPhaseChange,
	})
	brains[model] = brain
	active[model] = true

	humanoid.Died:Connect(function()
		brains[model] = nil
		active[model] = nil
		EntityRegistry.Unregister(model)
		if team ~= "Allies" and not options.NoRewards then
			Registry.Get("DropService"):HandleKill(entity, def)
		end
		EnemyService.EnemyDied:Fire(entity, def, options)
		if options.OnDeath then
			task.spawn(options.OnDeath, entity)
		end
		Registry.Get("FXService"):Play("Death", { Model = model, Color = def.AttackColor }, root.Position)
		task.delay(2.5, function()
			if model.Parent then
				model:Destroy()
			end
		end)
	end)
	return entity, brain
end

function EnemyService:GetBrain(model: Model)
	return brains[model]
end

-- SUMMONS (allies, e.g. Shadow Monarch) --------------------------------------------------------

function EnemyService:GetSummons(owner: Player?): { any }
	if not owner then
		return {}
	end
	local list = summonsByOwner[owner] or {}
	local alive = {}
	for _, entity in ipairs(list) do
		if EntityRegistry.IsAlive(entity) then
			table.insert(alive, entity)
		end
	end
	summonsByOwner[owner] = alive
	return alive
end

function EnemyService:SpawnSummons(ownerEntity, opts): { any }
	local owner = ownerEntity.Player
	if not owner then
		return {}
	end
	local existing = self:GetSummons(owner)
	local maxSummons = 10
	local spawned = {}
	local count = math.min(opts.Count or 1, maxSummons - #existing)
	for i = 1, count do
		local angle = (i / math.max(1, count)) * math.pi * 2
		local pos = ownerEntity.Root.Position + Vector3.new(math.cos(angle) * 6, 0, math.sin(angle) * 6)
		local def = {
			Id = "Summon",
			DisplayName = opts.Name or "Summon",
			Level = ownerEntity.Level,
			Behaviour = "Melee",
			Scale = opts.Scale or 1,
			HealthMultiplier = (opts.HealthMultiplier or 1) * 3,
			DamageMultiplier = (opts.DamageMultiplier or 1) * 1.5,
			AttackSpeed = 1.1,
			Range = 6,
			WalkSpeed = 24,
			AggroRange = 60,
			BlockChance = 0.2,
			DodgeChance = 0.1,
			Skills = { "Lunge" },
			Colors = { Body = opts.Color or Color3.new(0.05, 0.05, 0.1), Accent = opts.Accent or Color3.new(0.4, 0.2, 0.8) },
			AttackColor = opts.Accent,
			WeaponClass = "Katana",
		}
		local entity = self:Spawn(def, {
			Position = pos,
			Team = "Allies",
			Owner = owner,
			NoRewards = true,
			LeashRange = 200,
		})
		if entity then
			table.insert(spawned, entity)
			table.insert(existing, entity)
			Registry.Get("FXService"):Play("Summon", { Model = entity.Model, Color = opts.Accent or Color3.new(0.5, 0.2, 1) }, pos)
			task.delay(opts.Duration or 15, function()
				if entity.Model.Parent and entity.Humanoid.Health > 0 then
					entity.Humanoid.Health = 0
				end
			end)
		end
	end
	summonsByOwner[owner] = existing
	return spawned
end

function EnemyService:SpawnMinions(casterEntity, enemyId: string, count: number): { any }
	local list = {}
	for _ = 1, count do
		local offset = Vector3.new(rng:NextNumber(-12, 12), 0, rng:NextNumber(-12, 12))
		local entity = self:Spawn(enemyId, {
			Position = casterEntity.Root.Position + offset,
			Level = math.max(1, casterEntity.Level - 2),
			NoRespawn = true,
			HealthScale = 0.6,
			Folder = casterEntity.Model.Parent,
			Tag = casterEntity.Model:GetAttribute("Tag"),
		})
		if entity then
			table.insert(list, entity)
		end
	end
	return list
end

-- SPAWNERS -----------------------------------------------------------------------------------------

local function runSpawner(spawner)
	local alive = {}
	local function spawnOne()
		local angle = rng:NextNumber(0, math.pi * 2)
		local radius = rng:NextNumber(0, spawner.Radius)
		local pos = spawner.Center + Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
		local entity = EnemyService:Spawn(spawner.Enemy, {
			Position = pos,
			Home = pos,
			OnDeath = function()
				task.delay(spawner.RespawnTime or 15, function()
					alive[spawner] = (alive[spawner] or 1) - 1
				end)
			end,
		})
		if entity then
			alive[spawner] = (alive[spawner] or 0) + 1
		end
	end
	task.spawn(function()
		while true do
			if (alive[spawner] or 0) < spawner.Count then
				spawnOne()
				task.wait(0.5)
			else
				task.wait(2)
			end
		end
	end)
end

-- LOOP -----------------------------------------------------------------------------------------------

local function nearestPlayerDistance(position: Vector3): number
	local best = math.huge
	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root then
			best = math.min(best, (root.Position - position).Magnitude)
		end
	end
	return best
end

function EnemyService:Init()
	pcall(function()
		PhysicsService:RegisterCollisionGroup("NPCs")
		PhysicsService:CollisionGroupSetCollidable("NPCs", "NPCs", false)
	end)
	getFolder("Enemies")
	getFolder("Bosses")
	getFolder("Summons", getFolder("NPCs"))

	Registry.Get("DamageService").Damaged:Connect(function(attacker, target)
		local brain = brains[target.Model]
		if brain then
			brain:OnDamaged(attacker)
		end
	end)
	Registry.Get("CombatServer").AttackStarted:Connect(function(attacker)
		for model, brain in pairs(brains) do
			if active[model] and brain.Target == attacker then
				brain:OnThreat(attacker)
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		for _, entity in ipairs(summonsByOwner[player] or {}) do
			if entity.Model.Parent then
				entity.Model:Destroy()
			end
		end
		summonsByOwner[player] = nil
	end)
end

function EnemyService:Start()
	-- Wait for the world to exist before spawning.
	local world = Registry.Get("WorldBuilder")
	world:WaitUntilBuilt()
	for _, spawner in ipairs(WorldConfig.EnemySpawns) do
		runSpawner(spawner)
		task.wait(0.1)
	end

	-- Activation check (1 Hz) - NPCs far from every player sleep.
	task.spawn(function()
		local activation = GameConfig.World.EnemyActivationDistance
		while true do
			task.wait(1)
			for model, brain in pairs(brains) do
				if model.Parent then
					local root = brain.Entity.Root
					local near = nearestPlayerDistance(root.Position) < activation
					active[model] = near or brain.IsAlly or brain.Def.IsBoss
					if root.Position.Y < WorldConfig.KillY then
						brain.Entity.Humanoid.Health = 0
					end
				else
					brains[model] = nil
					active[model] = nil
				end
			end
		end
	end)

	-- AI tick loop (~6.5 Hz)
	while true do
		task.wait(0.15)
		local now = os.clock()
		for model, brain in pairs(brains) do
			if active[model] then
				local ok, err = pcall(brain.Tick, brain, now)
				if not ok then
					warn("[EnemyService] AI error on " .. model.Name .. ": " .. tostring(err))
				end
			end
		end
	end
end

return EnemyService
