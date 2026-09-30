--[[
	WorldEventService (ModuleScript)
	Location: ServerScriptService.Services.WorldEventService

	PHASE 19 - World Events: Meteor, Demon Invasion, World Boss, Portal, Treasure, Blood Moon,
	Thunder Storm. One event at a time, random interval (GameConfig.World.WorldEventIntervalRange).
	Participants (damaged event enemies / harvested event nodes) share the rewards.
	Workspace attribute "WorldEvent" = current event id (client shows a banner/timer).
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Modules = ReplicatedStorage.Modules
local GameConfig = require(Modules.Config.GameConfig)
local WorldEvents = require(Modules.World.WorldEvents)
local WorldConfig = require(Modules.World.WorldConfig)
local WeightedRandom = require(Modules.Shared.WeightedRandom)
local Registry = require(ServerScriptService.ServerModules.Registry)
local EntityRegistry = require(ServerScriptService.ServerModules.EntityRegistry)

local WorldEventService = {}

local rng = Random.new()
local current: any = nil

local function fx()
	return Registry.Get("FXService")
end

local function averageLevel(): number
	local total, count = 0, 0
	for _, player in ipairs(Players:GetPlayers()) do
		local data = Registry.Get("PlayerDataService"):Get(player)
		if data then
			total += data.Level
			count += 1
		end
	end
	return count > 0 and math.floor(total / count) or 10
end

local function regionLevel(region): number
	return math.floor((region.LevelRange[1] + region.LevelRange[2]) / 2)
end

-- Region with the most players (events happen where people are).
local function busiestRegion()
	local counts = {}
	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		local regionId = character and character:GetAttribute("Region")
		if regionId then
			counts[regionId] = (counts[regionId] or 0) + 1
		end
	end
	local best, bestCount = WorldConfig.Regions[1], -1
	for _, region in ipairs(WorldConfig.Regions) do
		if (counts[region.Id] or 0) > bestCount then
			best, bestCount = region, counts[region.Id] or 0
		end
	end
	return best
end

local function groundPoint(region): Vector3
	local center = region.Center
	for _ = 1, 10 do
		local pos = center + Vector3.new(rng:NextNumber(-200, 200), 0, rng:NextNumber(-200, 200))
		local hit = workspace:Raycast(pos + Vector3.new(0, 150, 0), Vector3.new(0, -400, 0))
		if hit then
			return hit.Position
		end
	end
	return center + Vector3.new(0, 3, 0)
end

local function spawnEventEnemy(enemyId: string, position: Vector3, level: number)
	return Registry.Get("EnemyService"):Spawn(enemyId, { Position = position, Level = level, Tag = "WorldEvent", LeashRange = 220 })
end

local function aliveTagged(): number
	local count = 0
	for model, entity in pairs(EntityRegistry.All()) do
		if model:GetAttribute("Tag") == "WorldEvent" and EntityRegistry.IsAlive(entity) then
			count += 1
		end
	end
	return count
end

local function clearTagged()
	for model in pairs(EntityRegistry.All()) do
		if model:GetAttribute("Tag") == "WorldEvent" then
			model:Destroy()
		end
	end
end

local function harvestNode(position: Vector3, itemId: string, color: Color3, lifetime: number)
	local node = Instance.new("Part")
	node.Name = "EventNode"
	node.Anchored = true
	node.CanCollide = false
	node.Shape = Enum.PartType.Ball
	node.Size = Vector3.new(3, 3, 3)
	node.Material = Enum.Material.Neon
	node.Color = color
	node.Position = position + Vector3.new(0, 1.5, 0)
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Collect"
	prompt.ObjectText = itemId
	prompt.HoldDuration = 0.5
	prompt.RequiresLineOfSight = false
	prompt.Parent = node
	local used = false
	prompt.Triggered:Connect(function(player)
		if used then
			return
		end
		used = true
		if current then
			current.Participants[player] = true
		end
		Registry.Get("DropService"):GiveItem(player, itemId, 1, nil, node.Position)
		node:Destroy()
	end)
	node.Parent = workspace:FindFirstChild("Interactables") or workspace
	task.delay(lifetime, function()
		if node.Parent then
			node:Destroy()
		end
	end)
end

-- EVENT IMPLEMENTATIONS -------------------------------------------------------------------------------

local Handlers = {}

function Handlers.Meteor(event)
	local region = busiestRegion()
	local level = regionLevel(region)
	local deadline = os.clock() + event.Def.Duration
	while os.clock() < deadline and not event.Stopped do
		local pos = groundPoint(region)
		fx():Play("Telegraph", { Position = pos, Radius = 14, Duration = 1.5, Color = Color3.fromRGB(255, 120, 40) }, pos)
		task.wait(1.5)
		fx():Play("Meteor", { Position = pos, Color = Color3.fromRGB(255, 120, 40), Size = 12 }, pos)
		fx():Play("Crater", { Position = pos, Size = 14 }, pos)
		for _, entity in pairs(EntityRegistry.All()) do
			if entity.Player and (entity.Root.Position - pos).Magnitude < 14 then
				entity.Humanoid:TakeDamage(entity.Humanoid.MaxHealth * 0.2)
			end
		end
		harvestNode(pos, "MeteorFragment", Color3.fromRGB(255, 130, 60), 90)
		if rng:NextNumber() < 0.6 then
			spawnEventEnemy("MeteorElemental", pos, level)
		end
		task.wait(rng:NextNumber(4, 8))
	end
	return true
end

function Handlers.DemonInvasion(event)
	local region = busiestRegion()
	local level = regionLevel(region) + 3
	for wave = 1, 3 do
		if event.Stopped then
			return false
		end
		fx():Notify(nil, "Event", string.format("Demon Invasion - wave %d/3 in %s!", wave, region.DisplayName))
		for _ = 1, 6 + wave * 2 do
			spawnEventEnemy("InvadingDemon", groundPoint(region), level)
		end
		local deadline = os.clock() + 90
		while aliveTagged() > 0 and os.clock() < deadline and not event.Stopped do
			task.wait(1)
		end
		if aliveTagged() > 0 then
			return false
		end
	end
	return true
end

function Handlers.WorldBoss(event)
	local spots = WorldConfig.WorldBossSpots
	local pos = spots[rng:NextInteger(1, #spots)]
	local dead = false
	local entity = Registry.Get("BossService"):SpawnBoss("RuinColossus", pos, {
		Level = math.clamp(averageLevel() + 5, 10, 205),
		Tag = "WorldEvent",
		HealthScale = 1 + #Players:GetPlayers() * 0.3,
		OnDeath = function()
			dead = true
		end,
	})
	fx():Notify(
		nil,
		"Event",
		"The Ruin Colossus appeared near " .. (WorldConfig.RegionAt(pos) and WorldConfig.RegionAt(pos).DisplayName or "the wilds") .. "!"
	)
	local deadline = os.clock() + event.Def.Duration
	while not dead and os.clock() < deadline and not event.Stopped do
		task.wait(1)
	end
	if not dead and entity and entity.Model.Parent then
		entity.Model:Destroy()
	end
	return dead
end

function Handlers.Portal(event)
	local region = busiestRegion()
	local level = regionLevel(region) + 5
	local pos = groundPoint(region)
	local portal = Instance.new("Part")
	portal.Name = "EventPortal"
	portal.Anchored = true
	portal.CanCollide = false
	portal.Shape = Enum.PartType.Cylinder
	portal.Size = Vector3.new(1, 18, 18)
	portal.CFrame = CFrame.new(pos + Vector3.new(0, 10, 0))
	portal.Color = Color3.fromRGB(150, 80, 255)
	portal.Material = Enum.Material.Neon
	portal.Transparency = 0.2
	portal.Parent = workspace:FindFirstChild("Interactables") or workspace
	-- The portal core is an entity players must destroy.
	local core = Registry.Get("EnemyService"):Spawn({
		Id = "PortalCore",
		DisplayName = "Portal Core",
		Level = level,
		Behaviour = "Caster",
		HealthMultiplier = 15 + #Players:GetPlayers() * 4,
		WalkSpeed = 0,
		AggroRange = 40,
		BlockChance = 0,
		DodgeChance = 0,
		Skills = { "Beam", "Fireball" },
		Colors = { Body = Color3.fromRGB(60, 20, 100), Accent = Color3.fromRGB(180, 100, 255) },
		AttackColor = Color3.fromRGB(180, 100, 255),
		Drops = { { Id = "PortalShard", Chance = 1, Min = 1, Max = 2 } },
	}, { Position = pos, Tag = "WorldEvent", LeashRange = 5 })
	local deadline = os.clock() + event.Def.Duration
	while os.clock() < deadline and not event.Stopped and core and EntityRegistry.IsAlive(core) do
		if aliveTagged() < 10 then
			spawnEventEnemy("PortalWraith", pos + Vector3.new(rng:NextNumber(-10, 10), 0, rng:NextNumber(-10, 10)), level)
		end
		fx():Play("Shockwave", { Position = pos, Color = Color3.fromRGB(150, 80, 255), Size = 24 }, pos)
		task.wait(6)
	end
	portal:Destroy()
	return core ~= nil and not EntityRegistry.IsAlive(core)
end

function Handlers.Treasure(event)
	local chests = {}
	for _, region in ipairs(WorldConfig.Regions) do
		for _ = 1, 2 do
			local pos = groundPoint(region)
			local chest = Instance.new("Part")
			chest.Name = "EventChest"
			chest.Anchored = true
			chest.Size = Vector3.new(4, 3, 3)
			chest.Position = pos + Vector3.new(0, 1.5, 0)
			chest.Color = Color3.fromRGB(255, 200, 60)
			chest.Material = Enum.Material.Neon
			local beam = Instance.new("Part")
			beam.Anchored = true
			beam.CanCollide = false
			beam.Size = Vector3.new(1, 120, 1)
			beam.Position = pos + Vector3.new(0, 60, 0)
			beam.Color = Color3.fromRGB(255, 220, 90)
			beam.Material = Enum.Material.Neon
			beam.Transparency = 0.5
			beam.Parent = chest
			local prompt = Instance.new("ProximityPrompt")
			prompt.ActionText = "Open"
			prompt.ObjectText = "Event Treasure"
			prompt.HoldDuration = 1
			prompt.RequiresLineOfSight = false
			prompt.Parent = chest
			local opened = false
			prompt.Triggered:Connect(function(player)
				if opened then
					return
				end
				opened = true
				event.Participants[player] = true
				local level = regionLevel(region)
				Registry.Get("DropService")
					:GrantRewards(player, { Gold = 200 + level * 120, Gems = rng:NextInteger(5, 15) }, "Event treasure found!")
				if rng:NextNumber() < 0.25 then
					Registry.Get("DropService"):GiveItem(player, "SpinToken", 1, nil, chest.Position)
				end
				chest:Destroy()
			end)
			chest.Parent = workspace:FindFirstChild("Interactables") or workspace
			table.insert(chests, chest)
		end
	end
	local deadline = os.clock() + event.Def.Duration
	while os.clock() < deadline and not event.Stopped do
		task.wait(1)
	end
	for _, chest in ipairs(chests) do
		if chest.Parent then
			chest:Destroy()
		end
	end
	return true
end

function Handlers.BloodMoon(event)
	workspace:SetAttribute("BloodMoon", true)
	local drops = Registry.Get("DropService")
	drops.GlobalLuck += 1
	drops.GlobalExp += 0.5
	local deadline = os.clock() + event.Def.Duration
	while os.clock() < deadline and not event.Stopped and workspace:GetAttribute("TimePhase") == "Night" do
		local region = busiestRegion()
		if aliveTagged() < 12 then
			spawnEventEnemy("BloodGhoul", groundPoint(region), regionLevel(region) + 5)
		end
		task.wait(8)
	end
	drops.GlobalLuck -= 1
	drops.GlobalExp -= 0.5
	workspace:SetAttribute("BloodMoon", false)
	return true
end

function Handlers.ThunderStorm(event)
	local environment = Registry.Get("EnvironmentService")
	workspace:SetAttribute("EventWeatherLock", true)
	environment:SetWeather("Storm")
	local deadline = os.clock() + event.Def.Duration
	while os.clock() < deadline and not event.Stopped do
		for _, player in ipairs(Players:GetPlayers()) do
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if root and rng:NextNumber() < 0.5 then
				local pos = root.Position + Vector3.new(rng:NextNumber(-25, 25), -2.5, rng:NextNumber(-25, 25))
				fx():Play("Telegraph", { Position = pos, Radius = 8, Duration = 1.2, Color = Color3.fromRGB(255, 255, 120) }, pos)
				task.delay(1.2, function()
					fx():Play(
						"Lightning",
						{ From = pos + Vector3.new(0, 120, 0), To = pos, Color = Color3.fromRGB(200, 220, 255), Thick = true },
						pos
					)
					for _, entity in pairs(EntityRegistry.All()) do
						if (entity.Root.Position - pos).Magnitude < 8 then
							entity.Humanoid:TakeDamage(entity.Humanoid.MaxHealth * 0.12)
						end
					end
					harvestNode(pos, "StormEssence", Color3.fromRGB(160, 180, 255), 45)
				end)
			end
		end
		task.wait(6)
	end
	workspace:SetAttribute("EventWeatherLock", false)
	environment:SetWeather("Clear")
	return true
end

-- RUNNER ---------------------------------------------------------------------------------------------

function WorldEventService:GetCurrent()
	return current
end

function WorldEventService:StartEvent(eventId: string): boolean
	local def = WorldEvents[eventId]
	local handler = Handlers[eventId]
	if not def or not handler or current then
		return false
	end
	if def.NightOnly and workspace:GetAttribute("TimePhase") ~= "Night" then
		return false
	end
	local event = { Id = eventId, Def = def, Participants = {}, Stopped = false }
	current = event
	workspace:SetAttribute("WorldEvent", eventId)
	workspace:SetAttribute("WorldEventEnds", os.time() + def.Duration)
	fx():Notify(nil, "Server", def.Message, { Event = eventId })
	local ok, success = pcall(handler, event)
	if not ok then
		warn("[WorldEvent] " .. eventId .. " error: " .. tostring(success))
		success = false
	end
	clearTagged()
	for player in pairs(event.Participants) do
		if player.Parent then
			if success then
				Registry.Get("DropService"):GrantRewards(player, def.Rewards, def.DisplayName .. " complete!")
				Registry.Get("PlayerDataService"):AddCounter(player, "EventsCompleted", 1)
			end
		end
	end
	fx():Notify(nil, "Event", string.format("%s has ended%s", def.DisplayName, success and " - participants were rewarded!" or "."))
	workspace:SetAttribute("WorldEvent", nil)
	current = nil
	return true
end

function WorldEventService:StopEvent()
	if current then
		current.Stopped = true
	end
end

function WorldEventService:Init()
	-- Anyone who damages an event enemy participates.
	Registry.Get("DamageService").Damaged:Connect(function(attacker, target)
		if current and attacker.Player and target.Model:GetAttribute("Tag") == "WorldEvent" then
			current.Participants[attacker.Player] = true
		end
	end)
end

function WorldEventService:Start()
	Registry.Get("WorldBuilder"):WaitUntilBuilt()
	local range = GameConfig.World.WorldEventIntervalRange
	while true do
		task.wait(rng:NextNumber(range[1], range[2]))
		if #Players:GetPlayers() > 0 and not current then
			local weights, order = {}, {}
			for id, def in pairs(WorldEvents) do
				if not def.NightOnly or workspace:GetAttribute("TimePhase") == "Night" then
					weights[id] = def.Weight
					table.insert(order, id)
				end
			end
			table.sort(order)
			local pick = WeightedRandom.PickKey(weights, rng, order)
			if pick then
				task.spawn(WorldEventService.StartEvent, WorldEventService, pick)
			end
		end
	end
end

return WorldEventService
