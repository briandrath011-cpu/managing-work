--[[
	TraitService (ModuleScript)
	Location: ServerScriptService.Services.TraitService
	Trait rolls (server RNG). Remote: TraitAction (RemoteFunction) ("Roll", payWithGems)
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Modules = ReplicatedStorage.Modules
local GameConfig = require(Modules.Config.GameConfig)
local RarityConfig = require(Modules.Config.RarityConfig)
local Traits = require(Modules.Progression.Traits)
local WeightedRandom = require(Modules.Shared.WeightedRandom)
local Net = require(Modules.Shared.Net)
local Registry = require(ServerScriptService.ServerModules.Registry)
local RateLimiter = require(ServerScriptService.ServerModules.RateLimiter)

local TraitService = {}

local rng = Random.new()
local limiter = RateLimiter.new(3, 1)

-- Builds weights: the rarity chance is split evenly between traits of that rarity.
local function buildEntries()
	local counts = {}
	for _, id in ipairs(Traits.Rollable) do
		local rarity = Traits.List[id].Rarity
		counts[rarity] = (counts[rarity] or 0) + 1
	end
	local entries = {}
	for _, id in ipairs(Traits.Rollable) do
		local rarity = Traits.List[id].Rarity
		table.insert(entries, { Id = id, Weight = (RarityConfig.TraitChances[rarity] or 0) / counts[rarity] })
	end
	return entries
end

local entries = buildEntries()

function TraitService:Roll(player: Player, payWithGems: boolean): (boolean, any)
	local dataService = Registry.Get("PlayerDataService")
	local data = dataService:Get(player)
	if not data then
		return false, "Data not loaded"
	end
	if payWithGems then
		if not dataService:SpendCurrency(player, "Gems", GameConfig.Traits.RollGemCost) then
			return false, "Need " .. GameConfig.Traits.RollGemCost .. " Gems"
		end
	elseif not dataService:SpendCurrency(player, "TraitRolls", 1) then
		return false, "No trait rolls left"
	end
	local picked = WeightedRandom.PickEntry(entries, rng)
	local id = picked and picked.Id or "Strong"
	data.Trait = id
	dataService:Replicate(player, "Trait")
	local trait = Traits.List[id]
	if RarityConfig.IsAtLeast(trait.Rarity, "Mythic") then
		Registry.Get("FXService"):Notify(
			nil,
			"Server",
			string.format("%s rolled the %s trait %s!", player.DisplayName, trait.Rarity, trait.DisplayName),
			{ Color = RarityConfig.GetColor(trait.Rarity) }
		)
	end
	return true, { Trait = id, Rarity = trait.Rarity }
end

function TraitService:Init()
	Net.Function("TraitAction").OnServerInvoke = function(player, action, payWithGems)
		if not limiter:Check(player) then
			return false, "Slow down"
		end
		if action == "Roll" then
			return TraitService:Roll(player, payWithGems == true)
		end
		return false, "Unknown action"
	end
end

return TraitService
