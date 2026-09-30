--[[
	AchievementService (ModuleScript)
	Location: ServerScriptService.Services.AchievementService
	Checks Progression.Achievements whenever counters, level, discovery or boss kills change.
	Grants rewards once (saved in PlayerData.Achievements).
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Modules = ReplicatedStorage.Modules
local Achievements = require(Modules.Progression.Achievements)
local PowerRegistry = require(Modules.Powers.PowerRegistry)
local RarityConfig = require(Modules.Config.RarityConfig)
local TableUtil = require(Modules.Shared.TableUtil)
local Registry = require(ServerScriptService.ServerModules.Registry)

local AchievementService = {}

local function progressFor(achievement, data): number
	local kind = achievement.Kind
	if kind == "Counter" then
		return data.Counters[achievement.Key] or 0
	elseif kind == "Level" then
		return data.Level
	elseif kind == "Boss" then
		return data.BossKills[achievement.Key] or 0
	elseif kind == "Regions" then
		return TableUtil.Count(data.Discovered.Regions)
	elseif kind == "PowerRarity" then
		for _, owned in pairs(data.Powers.Owned) do
			local def = PowerRegistry.Get(owned.Id)
			if def and RarityConfig.IsAtLeast(def.Rarity, achievement.Key) then
				return 1
			end
		end
		return 0
	end
	return 0
end

function AchievementService:Check(player: Player)
	local dataService = Registry.Get("PlayerDataService")
	local data = dataService:Get(player)
	if not data then
		return
	end
	local unlockedAny = false
	for _, achievement in ipairs(Achievements) do
		if not data.Achievements[achievement.Id] and progressFor(achievement, data) >= achievement.Goal then
			data.Achievements[achievement.Id] = os.time()
			unlockedAny = true
			Registry.Get("FXService"):Notify(player, "Achievement", "🏆 Achievement unlocked: " .. achievement.Name)
			Registry.Get("FXService"):PlayFor(player, "Achievement", { Name = achievement.Name })
			Registry.Get("DropService"):GrantRewards(player, achievement.Reward, nil)
		end
	end
	if unlockedAny then
		dataService:Replicate(player, "Achievements")
	end
end

function AchievementService:Init()
	local dataService = Registry.Get("PlayerDataService")
	local pending: { [Player]: boolean } = {}
	local function schedule(player: Player)
		if pending[player] then
			return
		end
		pending[player] = true
		task.delay(1, function()
			pending[player] = nil
			if player.Parent then
				AchievementService:Check(player)
			end
		end)
	end
	dataService.CounterChanged:Connect(schedule)
	dataService.LevelUp:Connect(schedule)
	dataService.ProfileLoaded:Connect(schedule)
	dataService.DataChanged:Connect(function(player, key)
		if key == "Discovered" or key == "BossKills" or key == "Powers" then
			schedule(player)
		end
	end)
end

return AchievementService
