--[[
	ExplorationService (ModuleScript)
	Location: ServerScriptService.Services.ExplorationService

	PHASE 15 / 18 - Exploration rewards
	- Region discovery (+ map reveal) and waypoint discovery (fast travel) by proximity
	- Secret spots (caves, parkour tops) with one-time rewards
	- Treasure chests (one-time per player, tiered loot)
	- Portals between regions (level gated)
	- Night-only resource nodes (Moonpetal)
	- Lava damage + void safety
	All checks run on the server from real character positions.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Modules = ReplicatedStorage.Modules
local WorldConfig = require(Modules.World.WorldConfig)
local Registry = require(ServerScriptService.ServerModules.Registry)
local EntityRegistry = require(ServerScriptService.ServerModules.EntityRegistry)
local Motion = require(ServerScriptService.ServerModules.Motion)

local ExplorationService = {}

local rng = Random.new()
local nodeCooldowns: { [Player]: { [number]: number } } = {}

local CHEST_LOOT = {
	[1] = {
		Gold = { 150, 400 },
		Gems = { 0, 3 },
		Items = { { Id = "HealthPotion", Chance = 0.8, Min = 1, Max = 3 }, { Id = "SpinToken", Chance = 0.05, Min = 1, Max = 1 } },
	},
	[2] = {
		Gold = { 600, 1500 },
		Gems = { 5, 10 },
		Items = {
			{ Id = "ExpScroll", Chance = 0.4, Min = 1, Max = 1 },
			{ Id = "SpinToken", Chance = 0.2, Min = 1, Max = 1 },
			{ Id = "WolfToothCharm", Chance = 0.15, Min = 1, Max = 1 },
		},
	},
	[3] = {
		Gold = { 3000, 8000 },
		Gems = { 10, 20 },
		Items = {
			{ Id = "LuckPotion", Chance = 0.35, Min = 1, Max = 1 },
			{ Id = "SpinToken", Chance = 0.35, Min = 1, Max = 2 },
			{ Id = "TraitToken", Chance = 0.15, Min = 1, Max = 1 },
		},
	},
	[4] = {
		Gold = { 15000, 40000 },
		Gems = { 20, 35 },
		Items = {
			{ Id = "SpinToken", Chance = 0.5, Min = 1, Max = 2 },
			{ Id = "BossCore", Chance = 0.15, Min = 1, Max = 1 },
			{ Id = "VoidCrystal", Chance = 0.4, Min = 1, Max = 3 },
		},
	},
	[5] = {
		Gold = { 80000, 200000 },
		Gems = { 40, 80 },
		Items = {
			{ Id = "SpinToken", Chance = 0.7, Min = 2, Max = 3 },
			{ Id = "DivineFragment", Chance = 0.4, Min = 1, Max = 2 },
			{ Id = "Stardust", Chance = 0.6, Min = 2, Max = 4 },
		},
	},
}

local function dataService()
	return Registry.Get("PlayerDataService")
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function discover(player: Player, data, category: string, id: string, displayName: string)
	if data.Discovered[category][id] then
		return false
	end
	data.Discovered[category][id] = true
	dataService():Replicate(player, "Discovered")
	local fx = Registry.Get("FXService")
	if category == "Regions" then
		fx:PlayFor(player, "RegionDiscovered", { Name = displayName })
	elseif category == "Waypoints" then
		fx:Notify(player, "Discover", "Waypoint discovered: " .. displayName .. " (Fast Travel unlocked)")
	end
	Registry.Get("QuestService"):OnEvent(player, { Kind = "Explore", Target = id })
	return true
end

function ExplorationService:OpenChest(player: Player, chestId: string)
	local data = dataService():Get(player)
	local root = rootOf(player)
	if not data or not root then
		return
	end
	local chest
	for _, entry in ipairs(WorldConfig.Chests) do
		if entry.Id == chestId then
			chest = entry
		end
	end
	if not chest or (chest.Position - root.Position).Magnitude > 14 then
		return
	end
	if data.Discovered.Chests[chestId] then
		Registry.Get("FXService"):Notify(player, "Error", "You already opened this chest.")
		return
	end
	data.Discovered.Chests[chestId] = true
	dataService():Replicate(player, "Discovered")
	dataService():AddCounter(player, "ChestsOpened", 1)
	local loot = CHEST_LOOT[chest.Tier] or CHEST_LOOT[1]
	local drops = Registry.Get("DropService")
	drops:GrantRewards(
		player,
		{ Gold = rng:NextInteger(loot.Gold[1], loot.Gold[2]), Gems = rng:NextInteger(loot.Gems[1], loot.Gems[2]) },
		nil
	)
	for _, drop in ipairs(drops:RollTable(loot.Items, 0)) do
		drops:GiveItem(player, drop.Id, drop.Amount, nil, chest.Position)
	end
	Registry.Get("FXService"):Play("ChestOpen", { Position = chest.Position, Tier = chest.Tier }, chest.Position)
	Registry.Get("FXService"):Notify(player, "Reward", "Treasure chest opened!")
end

function ExplorationService:UsePortal(player: Player, portalId: string)
	local data = dataService():Get(player)
	local root = rootOf(player)
	if not data or not root then
		return
	end
	for _, portal in ipairs(WorldConfig.Portals) do
		if portal.Id == portalId then
			if (portal.Position - root.Position).Magnitude > 16 then
				return
			end
			if data.Level < portal.LevelRequired then
				Registry.Get("FXService")
					:Notify(player, "Error", string.format("%s requires level %d.", portal.DisplayName, portal.LevelRequired))
				return
			end
			local entity = EntityRegistry.GetForPlayer(player)
			if entity then
				Registry.Get("FXService"):Play("Teleport", { Position = root.Position, Color = portal.Color }, root.Position)
				Motion.Teleport(entity, CFrame.new(portal.Target + Vector3.new(0, 3, 0)))
			end
			return
		end
	end
end

local function checkPlayer(player: Player)
	local data = dataService():Get(player)
	local root = rootOf(player)
	if not data or not root then
		return
	end
	local position = root.Position
	-- Regions
	local region = WorldConfig.RegionAt(position)
	if region then
		discover(player, data, "Regions", region.Id, region.DisplayName)
		local character = player.Character :: Model
		if character:GetAttribute("Region") ~= region.Id then
			character:SetAttribute("Region", region.Id)
		end
	end
	-- Waypoints
	for _, waypoint in ipairs(WorldConfig.Waypoints) do
		if (waypoint.Position - position).Magnitude < 18 then
			discover(player, data, "Waypoints", waypoint.Id, waypoint.DisplayName)
			if data.Discovered.LastWaypoint ~= waypoint.Id then
				data.Discovered.LastWaypoint = waypoint.Id
			end
		end
	end
	-- Secret spots
	for _, secret in ipairs(WorldConfig.Secrets) do
		if (secret.Position - position).Magnitude < secret.Radius and not data.Discovered.Secrets[secret.Id] then
			discover(player, data, "Secrets", secret.Id, secret.DisplayName)
			Registry.Get("FXService"):PlayFor(player, "SecretFound", { Name = secret.DisplayName })
			Registry.Get("DropService")
				:GrantRewards(player, { Gems = secret.Reward.Gems, Items = secret.Reward.Items }, "Secret found: " .. secret.DisplayName)
		end
	end
	-- Void safety
	if position.Y < WorldConfig.KillY then
		local entity = EntityRegistry.GetForPlayer(player)
		if entity then
			Motion.Teleport(entity, Registry.Get("CharacterService"):GetSpawnCFrame(player))
		end
	end
end

local function hookInteractables()
	local interactables = workspace:WaitForChild("Interactables")
	local function hook(descendant: Instance)
		if descendant:IsA("ProximityPrompt") then
			local model = descendant:FindFirstAncestorOfClass("Model")
			if not model then
				return
			end
			local chestId = model:GetAttribute("ChestId")
			local portalId = model:GetAttribute("PortalId")
			if chestId then
				descendant.Triggered:Connect(function(player)
					ExplorationService:OpenChest(player, chestId)
				end)
			elseif portalId then
				descendant.Triggered:Connect(function(player)
					ExplorationService:UsePortal(player, portalId)
				end)
			end
		end
	end
	for _, descendant in ipairs(interactables:GetDescendants()) do
		hook(descendant)
	end
	interactables.DescendantAdded:Connect(hook)
end

-- Night nodes: glowing flowers that only appear at night.
local function buildNightNodes()
	local interactables = workspace:WaitForChild("Interactables")
	local folder = Instance.new("Folder")
	folder.Name = "NightNodes"
	folder.Parent = interactables
	local nodes = {}
	for index, node in ipairs(WorldConfig.NightNodes) do
		local flower = Instance.new("Part")
		flower.Name = "Moonpetal"
		flower.Shape = Enum.PartType.Ball
		flower.Size = Vector3.new(2, 2, 2)
		flower.Anchored = true
		flower.CanCollide = false
		flower.Material = Enum.Material.Neon
		flower.Color = Color3.fromRGB(200, 200, 255)
		flower.Position = node.Position
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Harvest"
		prompt.ObjectText = "Moonpetal"
		prompt.HoldDuration = 0.8
		prompt.MaxActivationDistance = 10
		prompt.RequiresLineOfSight = false
		prompt.Parent = flower
		prompt.Triggered:Connect(function(player)
			local cooldowns = nodeCooldowns[player] or {}
			nodeCooldowns[player] = cooldowns
			if os.clock() < (cooldowns[index] or 0) then
				Registry.Get("FXService"):Notify(player, "Error", "This flower needs time to regrow.")
				return
			end
			cooldowns[index] = os.clock() + 120
			Registry.Get("DropService"):GiveItem(player, node.Item, 1, nil, node.Position)
		end)
		table.insert(nodes, flower)
	end
	local function refresh()
		local night = workspace:GetAttribute("TimePhase") == "Night"
		for _, flower in ipairs(nodes) do
			flower.Parent = night and folder or nil
		end
	end
	refresh()
	workspace:GetAttributeChangedSignal("TimePhase"):Connect(refresh)
end

function ExplorationService:Init()
	Players.PlayerRemoving:Connect(function(player)
		nodeCooldowns[player] = nil
	end)
end

function ExplorationService:Start()
	Registry.Get("WorldBuilder"):WaitUntilBuilt()
	hookInteractables()
	buildNightNodes()
	-- Lava damage via Touched (server side).
	local map = workspace:WaitForChild("Map")
	local burning: { [Model]: number } = {}
	for _, part in ipairs(map:GetDescendants()) do
		if part:IsA("BasePart") and part:GetAttribute("Lava") then
			part.CanTouch = true
			part.Touched:Connect(function(hit)
				local character = hit.Parent
				local entity = character and EntityRegistry.Get(character)
				if entity and entity.Player and os.clock() > (burning[character] or 0) then
					burning[character] = os.clock() + 0.5
					entity.Humanoid:TakeDamage(entity.Humanoid.MaxHealth * 0.06)
					Registry.Get("FXService")
						:Play("HitSpark", { Position = entity.Root.Position, Color = Color3.fromRGB(255, 100, 20) }, entity.Root.Position)
				end
			end)
		end
	end
	while true do
		task.wait(1)
		for _, player in ipairs(Players:GetPlayers()) do
			local ok, err = pcall(checkPlayer, player)
			if not ok then
				warn("[Exploration] " .. tostring(err))
			end
		end
	end
end

return ExplorationService
