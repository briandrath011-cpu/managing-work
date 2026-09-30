--[[
	Main (Script)
	Location: ServerScriptService.Main
	Boots every service in a fixed order: Init() all, then Start() all.
	Services live in ServerScriptService.Services as ModuleScripts.
]]
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Modules.Shared.Net)
local Registry = require(ServerScriptService.ServerModules.Registry)

Net.Setup()

-- Order matters: data first, world before enemies, etc.
local ORDER = {
	"PlayerDataService",
	"AntiExploitService",
	"EnvironmentService",
	"WorldBuilder",
	"CharacterService",
	"FXService",
	"MovementValidator",
	"DamageService",
	"CombatServer",
	"InventoryService",
	"WeaponService",
	"PowerService",
	"SpinService",
	"TraitService",
	"TransformationService",
	"DropService",
	"EnemyService",
	"BossService",
	"NPCService",
	"QuestService",
	"ExplorationService",
	"FastTravelService",
	"CraftingService",
	"ShopService",
	"DungeonService",
	"RaidService",
	"WorldEventService",
	"AchievementService",
	"DevCommandService",
}

local servicesFolder = ServerScriptService:WaitForChild("Services")

for _, name in ipairs(ORDER) do
	local moduleScript = servicesFolder:FindFirstChild(name)
	if moduleScript then
		local ok, result = pcall(require, moduleScript)
		if ok then
			Registry.Add(name, result)
		else
			warn("[Main] Failed to require " .. name .. ": " .. tostring(result))
		end
	else
		warn("[Main] Missing service module: " .. name)
	end
end

for _, name in ipairs(ORDER) do
	local service = Registry.Services[name]
	if service and service.Init then
		local ok, err = pcall(service.Init, service)
		if not ok then
			warn("[Main] Init failed for " .. name .. ": " .. tostring(err))
		end
	end
end

Registry.Started = true

for _, name in ipairs(ORDER) do
	local service = Registry.Services[name]
	if service and service.Start then
		task.spawn(function()
			local ok, err = pcall(service.Start, service)
			if not ok then
				warn("[Main] Start failed for " .. name .. ": " .. tostring(err))
			end
		end)
	end
end

print(string.format("[Main] %d services started", #ORDER))
