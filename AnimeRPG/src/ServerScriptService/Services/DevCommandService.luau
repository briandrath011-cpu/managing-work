--[[
	DevCommandService (ModuleScript)
	Location: ServerScriptService.Services.DevCommandService
	Testing commands, ONLY in Studio (or for GameConfig.Debug.AdminUserIds). Type in chat:
		/level 50        /exp 5000       /gold 100000     /gems 500      /spins 20
		/item NightSlayer 1              /mastery 100 (equipped power + weapon)
		/stats            (+100 stat points)             /awaken (fill awakening bar)
		/boss BanditChief /event Portal  /time 21         /weather Storm
		/tp Desert        /heal          /unlockall (all waypoints + flight)
		/power Rinnegan   (adds a power to storage and equips it)
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local Modules = ReplicatedStorage.Modules
local GameConfig = require(Modules.Config.GameConfig)
local WorldConfig = require(Modules.World.WorldConfig)
local ItemUtil = require(Modules.Items.ItemUtil)
local Progression = require(Modules.Config.Progression)
local PowerRegistry = require(Modules.Powers.PowerRegistry)
local Registry = require(ServerScriptService.ServerModules.Registry)
local EntityRegistry = require(ServerScriptService.ServerModules.EntityRegistry)
local Motion = require(ServerScriptService.ServerModules.Motion)

local DevCommandService = {}

local function isAllowed(player: Player): boolean
	if not GameConfig.Debug.EnableStudioCommands then
		return false
	end
	return RunService:IsStudio() or table.find(GameConfig.Debug.AdminUserIds, player.UserId) ~= nil
end

local commands = {}

commands.level = function(player, n)
	local dataService = Registry.Get("PlayerDataService")
	local data = dataService:Get(player)
	local target = math.clamp(tonumber(n) or 1, 1, GameConfig.Progression.MaxLevel)
	local needed = 0
	for level = data.Level, target - 1 do
		needed += Progression.ExpToNext(level)
	end
	dataService:AddExp(player, needed - data.Exp + 1)
end
commands.exp = function(player, n)
	Registry.Get("PlayerDataService"):AddExp(player, tonumber(n) or 1000)
end
commands.gold = function(player, n)
	Registry.Get("PlayerDataService"):AddCurrency(player, "Gold", tonumber(n) or 10000)
end
commands.gems = function(player, n)
	Registry.Get("PlayerDataService"):AddCurrency(player, "Gems", tonumber(n) or 100)
end
commands.spins = function(player, n)
	Registry.Get("PlayerDataService"):AddCurrency(player, "Spins", tonumber(n) or 10)
end
commands.item = function(player, id, n)
	if ItemUtil.Get(id) then
		Registry.Get("InventoryService"):AddItem(player, id, tonumber(n) or 1)
	else
		Registry.Get("FXService"):Notify(player, "Error", "Unknown item " .. tostring(id))
	end
end
commands.mastery = function(player, n)
	local amount = tonumber(n) or 100
	local power = Registry.Get("PowerService"):GetEquippedPower(player)
	if power then
		Registry.Get("PowerService"):AddMastery(player, power.Id, 1e7 * amount / 100)
	end
	local weapon = Registry.Get("WeaponService"):GetEquipped(player)
	if weapon then
		Registry.Get("WeaponService"):AddMastery(player, weapon.Def.Id, 1e7 * amount / 100)
	end
end
commands.stats = function(player)
	local dataService = Registry.Get("PlayerDataService")
	local data = dataService:Get(player)
	data.StatPoints += 100
	dataService:Replicate(player, "StatPoints")
end
commands.awaken = function(player)
	Registry.Get("TransformationService"):AddAwakening(player, 1000)
end
commands.boss = function(player, id)
	local character = player.Character
	if character then
		Registry.Get("BossService")
			:SpawnBoss(id or "BanditChief", character:GetPivot().Position + character:GetPivot().LookVector * 40, { Tag = "Dev" })
	end
end
commands.event = function(_, id)
	task.spawn(Registry.Get("WorldEventService").StartEvent, Registry.Get("WorldEventService"), id or "Portal")
end
commands.time = function(_, n)
	Registry.Get("EnvironmentService"):SetClock(tonumber(n) or 12)
end
commands.weather = function(_, name)
	Registry.Get("EnvironmentService"):SetWeather(name or "Clear")
end
commands.tp = function(player, regionId)
	local region = WorldConfig.GetRegion(regionId or "Greenwood")
	local entity = EntityRegistry.GetForPlayer(player)
	if region and entity then
		for _, waypoint in ipairs(WorldConfig.Waypoints) do
			if waypoint.Region == region.Id then
				Motion.Teleport(entity, CFrame.new(waypoint.Position + Vector3.new(0, 5, 0)))
				return
			end
		end
	end
end
commands.heal = function(player)
	local entity = EntityRegistry.GetForPlayer(player)
	if entity then
		entity.Humanoid.Health = entity.Humanoid.MaxHealth
	end
	Registry.Get("CharacterService"):RestoreEnergy(player, 1e6)
end
commands.power = function(player, id)
	local def = PowerRegistry.Get(id)
	if not def then
		error("Unknown power " .. tostring(id))
	end
	local dataService = Registry.Get("PlayerDataService")
	local data = dataService:Get(player)
	local uid = "dev" .. tostring(os.clock()):gsub("%.", "")
	data.Powers.Owned[uid] = { Id = def.Id, Locked = false, Obtained = os.time() }
	data.Powers.EquippedUid = uid
	dataService:Replicate(player, "Powers")
end

commands.unlockall = function(player)
	local dataService = Registry.Get("PlayerDataService")
	local data = dataService:Get(player)
	for _, waypoint in ipairs(WorldConfig.Waypoints) do
		data.Discovered.Waypoints[waypoint.Id] = true
	end
	for _, region in ipairs(WorldConfig.Regions) do
		data.Discovered.Regions[region.Id] = true
	end
	data.Unlocks.Flight = true
	dataService:Replicate(player, "Discovered")
	dataService:Replicate(player, "Unlocks")
	Registry.Get("CharacterService"):Refresh(player)
end

local function onChatted(player: Player, message: string)
	if message:sub(1, 1) ~= "/" or not isAllowed(player) then
		return
	end
	local args = string.split(message:sub(2), " ")
	local name = string.lower(table.remove(args, 1) or "")
	local command = commands[name]
	if command then
		local ok, err = pcall(command, player, table.unpack(args))
		Registry.Get("FXService"):Notify(player, ok and "Reward" or "Error", ok and ("Command /" .. name .. " done") or tostring(err))
	end
end

function DevCommandService:Init()
	local function hook(player: Player)
		player.Chatted:Connect(function(message)
			onChatted(player, message)
		end)
	end
	Players.PlayerAdded:Connect(hook)
	for _, player in ipairs(Players:GetPlayers()) do
		hook(player)
	end
end

DevCommandService.Commands = commands

return DevCommandService
